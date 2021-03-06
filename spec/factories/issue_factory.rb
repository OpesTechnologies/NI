FactoryBot.define do

  factory :issue do
    sequence(:title) {|n| "issue#{n}"}
    sequence(:number) {|n| n}
    release { DateTime.now }

    factory :published_issue do
    	published { true }
    end

    factory :published_trial_issue do
      published { true }
      trialissue { true }
    end

  end

end

