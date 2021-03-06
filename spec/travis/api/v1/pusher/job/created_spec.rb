require 'spec_helper'

describe Travis::Api::V1::Pusher::Job::Created do
  include Travis::Testing::Stubs

  let(:test) { stub_test(state: :created, started_at: nil, finished_at: nil) }
  let(:data) { Travis::Api::V1::Pusher::Job::Created.new(test).data }

  it 'data' do
    data.should == {
      'id' => test.id,
      'build_id' => test.source_id,
      'repository_id' => test.repository_id,
      'repository_slug' => 'svenfuchs/minimal',
      'number' => '2.1',
      'state' => 'created',
      'result' => nil,
      'queue' => 'builds.common',
      'log_id' => 1,
      'allow_failure' => false
    }
  end
end
