import * as Sentry from '~/sentry/sentry_browser_wrapper';
import axios from '~/lib/utils/axios_utils';
import { logError } from '~/lib/logger';
import { DEFAULT_SORTING_OPTION, SORTING_OPTIONS } from './constants';

function reportErrorAndThrow(e) {
  logError(e);
  Sentry.captureException(e);
  throw e;
}
// Provisioning API spec: https://gitlab.com/gitlab-org/opstrace/opstrace/-/blob/main/provisioning-api/pkg/provisioningapi/routes.go#L59
async function enableObservability(provisioningUrl) {
  try {
    // Note: axios.put(url, undefined, {withCredentials: true}) does not send cookies properly, so need to use the API below for the correct behaviour
    return await axios(provisioningUrl, {
      method: 'put',
      withCredentials: true,
    });
  } catch (e) {
    return reportErrorAndThrow(e);
  }
}

// Provisioning API spec: https://gitlab.com/gitlab-org/opstrace/opstrace/-/blob/main/provisioning-api/pkg/provisioningapi/routes.go#L37
async function isObservabilityEnabled(provisioningUrl) {
  try {
    const { data } = await axios.get(provisioningUrl, { withCredentials: true });
    if (data && data.status) {
      // we currently ignore the 'status' payload and just check if the request was successful
      // We might improve this as part of https://gitlab.com/gitlab-org/opstrace/opstrace/-/issues/2315
      return true;
    }
  } catch (e) {
    if (e.response.status === 404) {
      return false;
    }
    return reportErrorAndThrow(e);
  }
  return reportErrorAndThrow(new Error('Failed to check provisioning')); // eslint-disable-line @gitlab/require-i18n-strings
}

async function fetchTrace(tracingUrl, traceId) {
  try {
    if (!traceId) {
      throw new Error('traceId is required.');
    }

    const { data } = await axios.get(`${tracingUrl}/${traceId}`, {
      withCredentials: true,
    });

    return data;
  } catch (e) {
    return reportErrorAndThrow(e);
  }
}

/**
 * Filters (and operators) allowed by tracing query API
 */
const SUPPORTED_FILTERS = {
  durationMs: ['>', '<'],
  operation: ['=', '!='],
  service: ['=', '!='],
  period: ['='],
  traceId: ['=', '!='],
  attribute: ['='],
  // free-text 'search' temporarily ignored https://gitlab.com/gitlab-org/opstrace/opstrace/-/issues/2309
};

/**
 * Mapping of filter name to query param
 */
const FILTER_TO_QUERY_PARAM = {
  durationMs: 'duration_nano',
  operation: 'operation',
  service: 'service_name',
  period: 'period',
  traceId: 'trace_id',
  attribute: 'attribute',
};

const FILTER_OPERATORS_PREFIX = {
  '!=': 'not',
  '>': 'gt',
  '<': 'lt',
};

/**
 * Builds the query param name for the given filter and operator
 *
 * @param {String} filterName - The filter name
 * @param {String} operator - The operator
 * @returns String | undefined - Query param name
 */
function getFilterParamName(filterName, operator) {
  const paramKey = FILTER_TO_QUERY_PARAM[filterName];
  if (!paramKey) return undefined;

  if (operator === '=') {
    return paramKey;
  }

  const prefix = FILTER_OPERATORS_PREFIX[operator];
  if (prefix) {
    return `${prefix}[${paramKey}]`;
  }

  return undefined;
}

/**
 * Process `filterValue` and append the proper query params to the  `searchParams` arg
 *
 * It mutates `searchParams`
 *
 * @param {String} filterValue The filter value, in the format `attribute_name=attribute_value`
 * @param {String} filterOperator The filter operator
 * @param {URLSearchParams} searchParams The URLSearchParams object where to append the proper query params
 */
function handleAttributeFilter(filterValue, filterOperator, searchParams) {
  const [attrName, attrValue] = filterValue.split('=');
  if (attrName && attrValue) {
    if (filterOperator === '=') {
      searchParams.append('attr_name', attrName);
      searchParams.append('attr_value', attrValue);
    }
  }
}

/**
 * Builds URLSearchParams from a filter object of type { [filterName]: undefined | null | Array<{operator: String, value: any} }
 *  e.g:
 *
 *  filterObj =  {
 *      durationMs: [{operator: '>', value: '100'}, {operator: '<', value: '1000' }],
 *      operation: [{operator: '=', value: 'someOp' }],
 *      service: [{operator: '!=', value: 'foo' }]
 *    }
 *
 * It handles converting the filter to the proper supported query params
 *
 * @param {Object} filterObj : An Object representing filters
 * @returns URLSearchParams
 */
function filterObjToQueryParams(filterObj) {
  const filterParams = new URLSearchParams();

  Object.keys(SUPPORTED_FILTERS).forEach((filterName) => {
    const filterValues = filterObj[filterName] || [];
    const validFilters = filterValues.filter((f) =>
      SUPPORTED_FILTERS[filterName].includes(f.operator),
    );
    validFilters.forEach(({ operator, value: rawValue }) => {
      if (filterName === 'attribute') {
        handleAttributeFilter(rawValue, operator, filterParams);
      } else {
        const paramName = getFilterParamName(filterName, operator);
        let value = rawValue;
        if (filterName === 'durationMs') {
          // converting durationMs to duration_nano
          value *= 1000000;
        }
        if (paramName && value) {
          filterParams.append(paramName, value);
        }
      }
    });
  });
  return filterParams;
}

/**
 * Fetches traces with given tracing API URL and filters
 *
 * @param {String} tracingUrl : The API base URL
 * @param {Object} filters : A filter object of type: { [filterName]: undefined | null | Array<{operator: String, value: String} }
 *  e.g:
 *
 *    {
 *      durationMs: [ {operator: '>', value: '100'}, {operator: '<', value: '1000'}],
 *      operation: [ {operator: '=', value: 'someOp}],
 *      service: [ {operator: '!=', value: 'foo}]
 *    }
 *
 * @returns Array<Trace> : A list of traces
 */
async function fetchTraces(tracingUrl, { filters = {}, pageToken, pageSize, sortBy } = {}) {
  const params = filterObjToQueryParams(filters);
  if (pageToken) {
    params.append('page_token', pageToken);
  }
  if (pageSize) {
    params.append('page_size', pageSize);
  }
  const sortOrder = Object.values(SORTING_OPTIONS).includes(sortBy)
    ? sortBy
    : DEFAULT_SORTING_OPTION;
  params.append('sort', sortOrder);

  try {
    const { data } = await axios.get(tracingUrl, {
      withCredentials: true,
      params,
    });
    if (!Array.isArray(data.traces)) {
      throw new Error('traces are missing/invalid in the response'); // eslint-disable-line @gitlab/require-i18n-strings
    }
    return data;
  } catch (e) {
    return reportErrorAndThrow(e);
  }
}

async function fetchServices(servicesUrl) {
  try {
    const { data } = await axios.get(servicesUrl, {
      withCredentials: true,
    });

    if (!Array.isArray(data.services)) {
      throw new Error('failed to fetch services. invalid response'); // eslint-disable-line @gitlab/require-i18n-strings
    }

    return data.services;
  } catch (e) {
    return reportErrorAndThrow(e);
  }
}

async function fetchOperations(operationsUrl, serviceName) {
  try {
    if (!serviceName) {
      throw new Error('fetchOperations() - serviceName is required.');
    }
    if (!operationsUrl.includes('$SERVICE_NAME$')) {
      throw new Error('fetchOperations() - operationsUrl must contain $SERVICE_NAME$');
    }
    const url = operationsUrl.replace('$SERVICE_NAME$', serviceName);
    const { data } = await axios.get(url, {
      withCredentials: true,
    });

    if (!Array.isArray(data.operations)) {
      throw new Error('failed to fetch operations. invalid response'); // eslint-disable-line @gitlab/require-i18n-strings
    }

    return data.operations;
  } catch (e) {
    return reportErrorAndThrow(e);
  }
}

async function fetchMetrics(metricsUrl) {
  try {
    const { data } = await axios.get(metricsUrl, {
      withCredentials: true,
    });
    if (!Array.isArray(data.metrics)) {
      throw new Error('metrics are missing/invalid in the response'); // eslint-disable-line @gitlab/require-i18n-strings
    }
    return data;
  } catch (e) {
    return reportErrorAndThrow(e);
  }
}

export function buildClient(config) {
  if (!config) {
    throw new Error('No options object provided'); // eslint-disable-line @gitlab/require-i18n-strings
  }

  const { provisioningUrl, tracingUrl, servicesUrl, operationsUrl, metricsUrl } = config;

  if (typeof provisioningUrl !== 'string') {
    throw new Error('provisioningUrl param must be a string');
  }

  if (typeof tracingUrl !== 'string') {
    throw new Error('tracingUrl param must be a string');
  }

  if (typeof servicesUrl !== 'string') {
    throw new Error('servicesUrl param must be a string');
  }

  if (typeof operationsUrl !== 'string') {
    throw new Error('operationsUrl param must be a string');
  }

  if (typeof metricsUrl !== 'string') {
    throw new Error('metricsUrl param must be a string');
  }

  return {
    enableObservability: () => enableObservability(provisioningUrl),
    isObservabilityEnabled: () => isObservabilityEnabled(provisioningUrl),
    fetchTraces: (options) => fetchTraces(tracingUrl, options),
    fetchTrace: (traceId) => fetchTrace(tracingUrl, traceId),
    fetchServices: () => fetchServices(servicesUrl),
    fetchOperations: (serviceName) => fetchOperations(operationsUrl, serviceName),
    fetchMetrics: () => fetchMetrics(metricsUrl),
  };
}
