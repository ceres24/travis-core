require 'spec_helper'

describe Artifact::Log do
  include Support::ActiveRecord

  describe 'class methods' do
    let(:log)   { job.log }
    let(:job)   { Factory.create(:test, :log => Factory.create(:log, :content => '')) }
    let(:lines) { ["line 1\n", "line 2\n", 'line 3'] }

    before :each do
      Travis::Features.start
      Travis::Features.disable_for_all(:log_aggregation)
    end

    describe '#to_json' do
      it 'returns JSON representation of the record' do
        json = JSON.parse(job.log.to_json)
        json['log']['id'].should == job.log.id
      end
    end

    describe 'given no part number' do
      describe 'append' do
        it 'appends streamed build log chunks' do
          0.upto(2) { |ix| Artifact::Log.append(job.id, lines[ix]) }
          job.log.reload.content.should == lines.join
        end

        it 'filters out null chars' do
          Artifact::Log.expects(:update_all).with do |updates, *args|
            updates.last.should == 'abc'
          end
          Artifact::Log.append(job.id, "a\0b\0c")
        end

        it 'filters out triple null chars' do
          Artifact::Log.expects(:update_all).with do |updates, *args|
            updates.last.should == 'abc'
          end
          Artifact::Log.append(job.id, "a\000b\000c")
        end
      end
    end

    describe 'given a part number and :log_aggregation being activated' do
      before :each do
        Travis::Features.enable_for_all(:log_aggregation)
      end

      describe 'append' do
        it 'creates a log part with the given number' do
          Artifact::Log.append(log.id, lines.first, 1)
          log.parts.first.content.should == lines.first
        end

        it 'filters out null chars' do
          Artifact::Log.append(log.id, "a\0b\0c", 1)
          log.parts.first.content.should == 'abc'
        end

        it 'filters out triple null chars' do
          Artifact::Log.append(log.id, "a\000b\000c", 1)
          log.parts.first.content.should == 'abc'
        end
      end

      describe 'content' do
        it 'while not aggregated it returns the aggregated parts' do
          lines.each_with_index { |line, ix| Artifact::Log.append(log.id, line, ix) }
          log.content.should == lines.join
        end

        it 'if aggregated returns the aggregated parts' do
          log.update_attributes!(:content => 'content', :aggregated_at => Time.now)
          log.content.should == 'content'
        end
      end

      describe 'aggregate' do
        before :each do
          lines.each_with_index { |line, ix| Artifact::Log.append(log.id, line, ix) }
          Artifact::Log.append(log.id + 1, 'foo', 1)
          Artifact::Log.aggregate(log.id)
          log.reload
        end

        it 'aggregates the content parts' do
          log.content.should == lines.join
        end

        it 'sets aggregated_at' do
          log.aggregated_at.should == Time.now
        end

        it 'deletes the content parts from the parts table' do
          log.parts.should be_empty
        end
      end
    end
  end
end

