import {
  defaultDate,
  serializeParams,
  update2WeekFromNow,
  updateUrlWithQueryParams,
} from '~/vue_shared/access_tokens/utils';
import { getBaseURL, updateHistory } from '~/lib/utils/url_utility';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  updateHistory: jest.fn(),
}));

// Current date, `new Date()`, for these tests is 2020-07-06
describe('defaultDate', () => {
  describe('when max date is not present', () => {
    it('defaults to 30 days from now', () => {
      expect(defaultDate().getTime()).toBe(new Date('2020-08-05').getTime());
    });
  });

  describe('when max date is present', () => {
    it('defaults to 30 days from now if max date is later', () => {
      const maxDate = new Date('2021-01-01');
      expect(defaultDate(maxDate).getTime()).toBe(new Date('2020-08-05').getTime());
    });

    it('defaults max date if max date is sooner than 30 days', () => {
      const maxDate = new Date('2020-08-01');
      expect(defaultDate(maxDate).getTime()).toBe(new Date('2020-08-01').getTime());
    });
  });
});

describe('serializeParams', () => {
  it('returns correct params for the fetch', () => {
    expect(
      serializeParams(
        [
          'my token',
          {
            type: 'created',
            value: { data: '2025-01-01', operator: '<' },
          },
          {
            type: 'expires',
            value: { data: '2025-01-02', operator: '<' },
          },
          {
            type: 'last_used',
            value: { data: '2025-01-03', operator: '≥' },
          },
          {
            type: 'state',
            value: { data: 'inactive', operator: '=' },
          },
        ],
        2,
      ),
    ).toMatchObject({
      created_before: '2025-01-01',
      expires_before: '2025-01-02',
      last_used_after: '2025-01-03',
      page: 2,
      search: 'my token',
      state: 'inactive',
    });
  });
});

describe('update2WeekFromNow', () => {
  const param = [
    {
      title: 'dummy',
      tooltipTitle: 'dummy',
      filters: [{ type: 'dummy', value: { data: 'DATE_HOLDER', operator: 'dummy' } }],
    },
  ];

  it('replace `DATE_HOLDER` with date 2 weeks from now', () => {
    expect(update2WeekFromNow(param)).toMatchObject([
      {
        title: 'dummy',
        tooltipTitle: 'dummy',
        filters: [{ type: 'dummy', value: { data: '2020-07-20', operator: 'dummy' } }],
      },
    ]);
  });

  it('use default parameter', () => {
    expect(update2WeekFromNow()).toBeDefined();
  });

  it('returns a clone of the original parameter', () => {
    const result = update2WeekFromNow(param);
    expect(result).not.toBe(param);
    expect(result[0].filters).not.toBe(param[0].filters);
  });
});

describe('updateUrlWithQueryParams', () => {
  it('calls updateHistory with correct parameters', () => {
    updateUrlWithQueryParams({ params: { page: 1, revoked: true }, sort: 'name_asc' });

    expect(updateHistory).toHaveBeenCalledWith({
      url: `${getBaseURL()}/?page=1&revoked=true&sort=name_asc`,
      replace: true,
    });
  });
});
