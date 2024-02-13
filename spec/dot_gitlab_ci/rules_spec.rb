# frozen_string_literal: true

require 'fast_spec_helper'

PatternsList = Struct.new(:name, :patterns)

RSpec.describe '.gitlab/ci/rules.gitlab-ci.yml', feature_category: :tooling do
  config = YAML.safe_load_file(
    File.expand_path('../../.gitlab/ci/rules.gitlab-ci.yml', __dir__),
    aliases: true
  ).freeze

  context 'with changes' do
    config.each do |name, definition|
      next unless definition.is_a?(Hash) && definition['rules']

      definition['rules'].each do |rule|
        next unless rule.is_a?(Hash) && rule['changes']

        # See this for why we want to always have if
        # https://docs.gitlab.com/ee/development/pipelines/internals.html#avoid-force_gitlab_ci
        it "#{name} has corresponding if" do
          expect(rule).to include('if')
        end
      end
    end
  end

  describe 'start-as-if-foss' do
    let(:base_rules) { config.dig('.as-if-foss:rules:start-as-if-foss', 'rules') }

    context 'with .as-if-foss:rules:start-as-if-foss:allow-failure:manual' do
      let(:derived_rules) { config.dig('.as-if-foss:rules:start-as-if-foss:allow-failure:manual', 'rules') }

      it 'has the same rules as the base and also allow-failure and manual' do
        base_rules.zip(derived_rules).each do |(base, derived)|
          # !references should be the same. Stop rules should be the same.
          if base.is_a?(Array) || base['when'] == 'never'
            expect(base).to eq(derived)
          else
            expect(derived).to eq(
              base.merge('allow_failure' => true, 'when' => 'manual'))
          end
        end
      end
    end

    context 'with .as-if-foss:rules:start-as-if-foss:allow-failure' do
      let(:derived_rules) { config.dig('.as-if-foss:rules:start-as-if-foss:allow-failure', 'rules') }

      it 'has the same rules as the base and also allow-failure' do
        base_rules.zip(derived_rules).each do |(base, derived)|
          # !references should be the same. Stop rules should be the same.
          if base.is_a?(Array) || base['when'] == 'never'
            expect(base).to eq(derived)
          else
            expect(derived).to eq(base.merge('allow_failure' => true))
          end
        end
      end
    end
  end

  describe 'patterns' do
    foss_context = !Gitlab.ee?
    no_matching_needed_files = (
      [
        '.byebug_history',
        '.editorconfig',
        '.eslintcache',
        '.foreman',
        '.git-blame-ignore-revs',
        '.gitlab_kas_secret',
        '.gitlab_shell_secret',
        '.gitlab_workhorse_secret',
        '.gitlab/agents/review-apps/config.yaml',
        '.gitlab/changelog_config.yml',
        '.gitlab/CODEOWNERS',
        '.gitleaksignore',
        '.gitpod.yml',
        '.license_encryption_key.pub',
        '.mailmap',
        '.prettierignore',
        '.projections.json.example',
        '.rubocop_revert_ignores.txt',
        '.ruby-version',
        '.solargraph.yml.example',
        '.solargraph.yml',
        '.test_license_encryption_key.pub',
        '.tool-versions',
        '.vale.ini',
        '.vscode/extensions.json',
        'ee/lib/ee/gitlab/background_migration/.rubocop.yml',
        'ee/LICENSE',
        'Gemfile.checksum',
        'gems/error_tracking_open_api/.openapi-generator/FILES',
        'gems/error_tracking_open_api/.openapi-generator/VERSION',
        'Guardfile',
        'INSTALLATION_TYPE',
        'lib/gitlab/background_migration/.rubocop.yml',
        'lib/gitlab/ci/templates/.yamllint',
        'LICENSE',
        'Pipfile.lock',
        'storybook/.env.template',
        'yarn-error.log'
      ] +
      Dir.glob('.bundle/**/*') +
      Dir.glob('.github/*') +
      Dir.glob('.gitlab/{issue,merge_request}_templates/**/*') +
      Dir.glob('.gitlab/*.toml') +
      Dir.glob('{,**/}.{DS_Store,eslintrc.yml,gitignore,gitkeep,keep}', File::FNM_DOTMATCH) +
      Dir.glob('{,vendor/}gems/*/.*') +
      Dir.glob('{.git,.lefthook,.ruby-lsp}/**/*') +
      Dir.glob('{file_hooks,log}/**/*') +
      Dir.glob('{metrics_server,sidekiq_cluster}/*') +
      Dir.glob('{spec/fixtures,tmp}/**/*', File::FNM_DOTMATCH) +
      Dir.glob('*.md') +
      Dir.glob('changelogs/*') +
      Dir.glob('doc/.{markdownlint,vale}/**/*') +
      Dir.glob('keeps/**/*') +
      Dir.glob('node_modules/**/*', File::FNM_DOTMATCH) +
      Dir.glob('patches/*') +
      Dir.glob('public/assets/**/.*') +
      Dir.glob('qa/.{,**/}*') +
      Dir.glob('qa/**/.gitlab-ci.yml') +
      Dir.glob('shared/**/*') +
      Dir.glob('workhorse/.*')
    ).freeze
    no_matching_needed_files_ci_specific = (
      [
        'metrics.txt'
      ] +
      Dir.glob('{auto_explain,crystalball,knapsack,rspec}/**/*') +
      Dir.glob('coverage/**/*', File::FNM_DOTMATCH) +
      Dir.glob('vendor/ruby/**/*', File::FNM_DOTMATCH)
    ).freeze
    all_files = Dir.glob('{,**/}*', File::FNM_DOTMATCH) -
      no_matching_needed_files -
      no_matching_needed_files_ci_specific
    all_files -= Dir.glob('ee/**/*', File::FNM_DOTMATCH) if foss_context
    all_files.reject! { |f| File.directory?(f) }

    # One loop to construct an array of PatternsList objects
    patterns_lists = config.filter_map do |name, patterns|
      next unless name.start_with?('.')
      next unless name.end_with?('patterns')
      # Ignore EE-only patterns list when in FOSS context
      next if foss_context && patterns.all? { |pattern| pattern =~ %r|{?ee/| }

      PatternsList.new(name, patterns)
    end

    # One loop to gather a { pattern => files } hash
    patterns_files = patterns_lists.each_with_object({}) do |patterns_list, memo|
      patterns_list.patterns.each do |pattern|
        memo[pattern] ||= Dir.glob(pattern)
      end
    end

    # Example: '.ci-patterns': [".gitlab-ci.yml", ".gitlab/ci/**/*", "scripts/rspec_helpers.sh"]
    patterns_lists.each do |patterns_list|
      describe "patterns list `#{patterns_list.name}`" do
        patterns_list.patterns.each do |pattern|
          pattern_files = patterns_files.fetch(pattern)

          context "with `#{pattern}`" do
            it 'matches' do
              matching_files = (all_files & pattern_files)

              expect(matching_files).not_to be_empty
            end
          end
        end
      end
    end

    describe 'missed matched files' do
      all_matching_files = Set.new

      patterns_files.each_value do |files|
        all_matching_files.merge(files)
      end

      it 'does not miss files to match' do
        expect(all_files - all_matching_files.to_a).to be_empty
      end
    end
  end
end
