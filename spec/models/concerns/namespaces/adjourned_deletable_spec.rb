# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::AdjournedDeletable, feature_category: :groups_and_projects do
  let(:model) do
    Class.new do
      include Namespaces::AdjournedDeletable
    end
  end

  let(:record) { model.new }

  describe '#delayed_deletion_ready?' do
    context 'when deletion_adjourned_period is zero' do
      before do
        stub_application_setting(deletion_adjourned_period: 0)
      end

      it 'returns false' do
        expect(record.delayed_deletion_ready?).to be(false)
        expect(record.adjourned_deletion?).to be(false)
        expect(record.delayed_deletion_configured?).to be(false)
        expect(record.adjourned_deletion_configured?).to be(false)
      end
    end

    context 'when deletion_adjourned_period is positive' do
      before do
        stub_application_setting(deletion_adjourned_period: 7)
      end

      it 'returns true' do
        expect(record.delayed_deletion_ready?).to be(true)
        expect(record.adjourned_deletion?).to be(true)
        expect(record.delayed_deletion_configured?).to be(true)
        expect(record.adjourned_deletion_configured?).to be(true)
      end
    end
  end

  describe '#self_deletion_scheduled_deletion_created_on', :freeze_time do
    context 'when record responds to :marked_for_deletion_on' do
      it 'returns marked_for_deletion_on' do
        allow(record).to receive(:marked_for_deletion_on).and_return(Time.current)

        expect(record.self_deletion_scheduled_deletion_created_on).to eq(Time.current)
      end
    end

    context 'when record does not respond to :marked_for_deletion_on' do
      it 'returns nil' do
        expect(record.self_deletion_scheduled_deletion_created_on).to be_nil
      end
    end
  end

  describe '#self_deletion_scheduled?' do
    context 'when self_deletion_scheduled_deletion_created_on is nil' do
      it 'returns false' do
        expect(record.self_deletion_scheduled?).to be(false)
        expect(record.marked_for_deletion?).to be(false)
      end
    end

    context 'when self_deletion_scheduled_deletion_created_on is present' do
      before do
        allow(record).to receive(:self_deletion_scheduled_deletion_created_on).and_return(Time.current)
      end

      it 'returns true' do
        expect(record.self_deletion_scheduled?).to be(true)
        expect(record.marked_for_deletion?).to be(true)
      end
    end
  end

  describe '#first_scheduled_for_deletion_in_hierarchy_chain' do
    it 'returns nil' do
      expect(record.first_scheduled_for_deletion_in_hierarchy_chain).to be_nil
    end
  end

  describe Group do
    let_it_be_with_reload(:group) { create(:group) }

    describe '#first_scheduled_for_deletion_in_hierarchy_chain' do
      context 'when the group has been marked for deletion' do
        before do
          create(:group_deletion_schedule, group: group, marked_for_deletion_on: 1.day.ago)
        end

        it 'returns the group' do
          expect(group.first_scheduled_for_deletion_in_hierarchy_chain).to eq(group)
        end
      end

      context 'when the parent group has been marked for deletion' do
        let(:parent_group) { create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago) }
        let(:group) { create(:group, parent: parent_group) }

        it 'returns the parent group' do
          expect(group.first_scheduled_for_deletion_in_hierarchy_chain).to eq(parent_group)
        end
      end

      context 'when parent group has not been marked for deletion' do
        let(:parent_group) { create(:group) }
        let(:group) { create(:group, parent: parent_group) }

        it 'returns nil' do
          expect(group.first_scheduled_for_deletion_in_hierarchy_chain).to be_nil
        end
      end

      describe 'ordering of parents marked for deletion' do
        let(:group_a) { create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago) }
        let(:subgroup_a) { create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago, parent: group_a) }
        let(:group) { create(:group, parent: subgroup_a) }

        it 'returns the ancestors marked for deletion, ordered from closest to farthest' do
          expect(group.first_scheduled_for_deletion_in_hierarchy_chain).to eq(subgroup_a)
        end
      end
    end
  end

  describe Project do
    let_it_be(:project) { create(:project) }

    describe '#first_scheduled_for_deletion_in_hierarchy_chain' do
      context 'when the parent group has been marked for deletion' do
        let_it_be(:parent_group) do
          create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago)
        end

        let_it_be(:project) { create(:project, namespace: parent_group) }

        it 'returns the parent group' do
          expect(project.first_scheduled_for_deletion_in_hierarchy_chain).to eq(parent_group)
        end
      end

      context 'when parent group has not been marked for deletion' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:project) { create(:project, namespace: parent_group) }

        it 'returns nil' do
          expect(project.first_scheduled_for_deletion_in_hierarchy_chain).to be_nil
        end
      end

      describe 'ordering of parents marked for deletion' do
        let_it_be(:group_a) { create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago) }
        let_it_be(:subgroup_a) do
          create(:group_with_deletion_schedule, marked_for_deletion_on: 1.day.ago, parent: group_a)
        end

        let_it_be(:project) { create(:project, namespace: subgroup_a) }

        it 'returns the ancestors marked for deletion, ordered from closest to farthest' do
          expect(project.first_scheduled_for_deletion_in_hierarchy_chain).to eq(subgroup_a)
        end
      end
    end
  end
end
