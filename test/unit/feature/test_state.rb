require_relative '../../helper'

describe 'Feature' do
  before do
    @feature = Fundry::Feature.create state: 'new', project_id: 1, name: 'test', detail: 'test'
  end

  [
    { old: 'pending',  new: 'new'      },
    { old: 'complete', new: 'pending'  },
    { old: 'complete', new: 'rejected' },
    { old: 'rejected', new: 'complete' },
    { old: 'rejected', new: 'pending'  },
  ].each do |state|
    it "must not allow state change from #{state[:old]} to #{state[:new]}" do
      @feature.state = state[:old]
      assert_raises Fundry::FeatureStateError do
        Fundry::FeatureState.create feature: @feature, status: state[:new]
      end
    end
  end

  [
    { old: 'new'    ,  new: 'pending'  },
    { old: 'pending' , new: 'rejected' },
    { old: 'pending' , new: 'complete' },
  ].each do |state|
    it "should allow change state from #{state[:old]} to #{state[:new]}" do
      @feature.state = state[:old]
      assert true, Fundry::FeatureState.create(feature: @feature, status: state[:new])
    end
  end
end
