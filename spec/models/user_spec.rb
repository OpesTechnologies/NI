require 'rails_helper'
require 'cancan/matchers'

describe User, :type => :model do

  context "institution" do
    let(:user) do
      FactoryBot.create(:user, :institution => true)
    end

    let(:ability) { Ability.new(user) }

    context "with a child" do
      before(:each) do
        child = FactoryBot.create(:user)
        user.children << child
      end
      it "can manage child" do
        expect(ability).to be_able_to(:manage, user.children.first)
      end
      it "destroys child when destroyed" do
        child_id = user.children.first.id
        user.destroy
        expect { User.find(child_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it "can create a child without an email" do
      newuser = FactoryBot.build(:user)
      child = user.children.create(username: newuser.username, password: newuser.password)
      expect(child.email).to be_blank
    end

  end

  context "normal user" do
    let(:user) do
      FactoryBot.create(:user)
    end
  
    let(:ability) { Ability.new(user) }

    it "should have a username" do
      expect(user.username).not_to eq("")
    end

    it "should not have a uk_id" do
      expect(user.uk_id).to be_nil
    end

    it "should not have a uk_expiry" do
      expect(user.uk_expiry).to be_nil
    end

    it "should not be a subscriber" do
      expect(user.subscriber?).to be_falsey
    end

    it "should not be able to manage an issue" do
      issue = FactoryBot.create(:issue)
      expect(ability).not_to be_able_to(:manage, issue)
    end

    it "should be able to read an issue" do
      issue = FactoryBot.create(:issue, :published => true)
      expect(ability).to be_able_to(:read, issue)
    end

    it "should not be able to read an article" do
      article = FactoryBot.create(:article)
      expect(ability).not_to be_able_to(:read, article)
    end

    it "should not be able to manage an article" do
      article = FactoryBot.create(:article)
      expect(ability).not_to be_able_to(:manage, article)
    end

    it "should not be able to read an unpublished article" do
      article = FactoryBot.create(:article, :unpublished => true)
      expect(ability).not_to be_able_to(:read, article)
    end

    it "should be able to read a trial article" do
      article = FactoryBot.create(:article, :trialarticle => true)
      expect(ability).to be_able_to(:read, article)
    end

    it "should be able to read a trial issue's article" do
      article = FactoryBot.create(:article)
      article.issue.trialissue = true
      expect(ability).to be_able_to(:read, article)
    end

    it "should not be able to manage a push registration" do
      push_registration = FactoryBot.create(:push_registration)
      expect(ability).not_to be_able_to(:manage, push_registration)
    end

    it "should not be able to manage a payment notifications" do
      payment_notification = FactoryBot.create(:payment_notification)
      expect(ability).not_to be_able_to(:manage, payment_notification)
    end

    context "without a parent" do
      it "can update itself" do
        expect(ability).to be_able_to(:manage, user)
      end
    end

    context "with a subscriber parent" do
      before(:each) do
        sub = FactoryBot.create(:subscription)
        sub.user.children << user
      end
      it "has a subscription" do
        expect(user.subscriber?).to be_truthy
      end
      it "can't update itself" do
        expect(ability).not_to be_able_to(:update, user)
      end
      it "doesn't destroy parent when destroyed" do
        parent_id = user.parent.id
        user.destroy
        expect(User.find(parent_id)).not_to be_nil
      end
    end

    context "with a child" do
      before(:each) do
        child = FactoryBot.create(:user)
        user.children << child
      end
      it "can manage child" do
        expect(ability).to be_able_to(:manage, user.children.first)
      end
      it "cannot manage a non-child user" do
        sibling = FactoryBot.create(:user)
        expect(ability).not_to be_able_to(:manage, sibling)
      end
    end

  end

  context "uk user" do
    let(:user) do
      FactoryBot.create(:uk_user)
    end
  
    let(:ability) { Ability.new(user) }

    it "should have a username" do
      expect(user.username).not_to eq("")
    end

    it "should have a uk_id" do
      expect(user.uk_id).to be_truthy
    end

    it "should have a uk_expiry" do
      expect(user.uk_expiry).to be_truthy
    end

    it "should not be a subscriber" do
      expect(user.subscriber?).to be_falsey
    end
  end

  context "subscriber" do

    before(:all) do
      Timecop.freeze(2012,1,1,0,0,0)
    end

    after(:all) do
      Timecop.return() 
    end
  
    let(:subscription) { FactoryBot.create(:subscription) }
    let(:user) { subscription.user }

    let(:ability) { Ability.new(user) }

    it "has a valid subscription" do
      expect(user.subscriber?).to be_truthy
    end

    it "should be able to read an article" do
      article = FactoryBot.create(:article)
      expect(ability).to be_able_to(:read, article)
    end

    it "should not be able to manage an article" do
      article = FactoryBot.create(:article)
      expect(ability).not_to be_able_to(:manage, article)
    end

    it "should not be able to manage a push registration" do
      push_registration = FactoryBot.create(:push_registration)
      expect(ability).not_to be_able_to(:manage, push_registration)
    end

    it "should not be able to manage a payment notifications" do
      payment_notification = FactoryBot.create(:payment_notification)
      expect(ability).not_to be_able_to(:manage, payment_notification)
    end

    it "receives a partial refund" do
      #set a predicatable duration
      subscription.duration = 3
      #price is 1 cent per day 
      subscription.price_paid = 91 
      Timecop.freeze(2012,1,22,0,0,0) do
        subscription.expire_subscription
        expect(subscription.refund).to eq(91-21)
      end
    end

    it "receives a full refund if the subscription hasn't started yet" do
      subscription.price_paid = 91
      Timecop.freeze(2011,1,1,0,0,0) do
        subscription.expire_subscription
        expect(subscription.refund).to eq(91)
      end
    end

    it "with two subscriptions, has the correct expiry date" do
      subscription.duration = 3
      subscription.price_paid = 91
      user.subscriptions.new(valid_from: (user.last_subscription.try(:expiry_date) or DateTime.now), duration: 3, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        expect(user.subscriptions.count).to eq(2)
        total_months = 0
        user.subscriptions.each do |s|
          if s.is_current?
            total_months += s.duration
          end
        end
        expect(user.subscriptions.first.valid_from + total_months.months).to eq(user.expiry_date)
        expect(user.expiry_date_paper_only).to be_nil
        expect(user.expiry_date_paper_copy).to be_nil
      end
    end

    it "with two subscriptions, the first refunded, has the correct expiry date" do
      subscription.duration = 3
      subscription.price_paid = 91
      user.subscriptions.new(valid_from: (user.last_subscription.try(:expiry_date) or DateTime.now), duration: 3, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        subscription.refunded_on = DateTime.now
        subscription.expire_subscription
        expect(user.subscriptions.count).to eq(2)
        # TODO: fix this in the subscription.rb model
        # expect(user.subscriptions.last.purchase_date + (user.subscriptions.last.duration).months).to eq(user.expiry_date)
        expect(user.expiry_date_paper_only).to be_nil
        expect(user.expiry_date_paper_copy).to be_nil
      end
    end

    it "with two subscriptions, the second refunded, has the correct expiry date" do
      subscription.duration = 3
      user.subscriptions.new(valid_from: (user.last_subscription.try(:expiry_date) or DateTime.now), duration: 3, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        user.subscriptions.last.refunded_on = DateTime.now
        user.subscriptions.last.expire_subscription
        expect(user.subscriptions.count).to eq(2)
        expect(user.subscriptions.first.purchase_date + (user.subscriptions.first.duration).months).to eq(user.expiry_date)
        expect(user.expiry_date_paper_only).to be_nil
        expect(user.expiry_date_paper_copy).to be_nil
      end
    end

    it "with two subscriptions, the first digital, the second paper only, has the correct expiry date and paper expiry date" do
      subscription.duration = 12
      user.subscriptions.new(valid_from: DateTime.now, duration: 12, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        expect(user.subscriptions.count).to eq(2)
        expect(user.subscriptions.first.purchase_date + (user.subscriptions.first.duration).months).to eq(user.expiry_date)
        expect(user.subscriptions.last.purchase_date + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_only)
        expect(user.subscriptions.last.valid_from + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_copy)
        expect(user.has_paper_copy?).to be_truthy
        expect(user.has_paper_only?).to be_truthy
      end
    end

    it "with two subscriptions, the first an expired digital, the second paper only, has the correct expiry date and paper expiry date" do
      subscription.duration = 12
      subscription.valid_from = DateTime.now - 18.months
      subscription.purchase_date = DateTime.now - 18.months
      subscription.save
      user.subscriptions.new(valid_from: DateTime.now, duration: 12, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        expect(user.subscriptions.count).to eq(2)
        expect(user.subscriptions.last.purchase_date + 3.months).to eq(user.expiry_date)
        expect(user.subscriptions.last.purchase_date + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_only)
        expect(user.subscriptions.last.valid_from + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_copy)
        expect(user.has_paper_copy?).to be_truthy
        expect(user.has_paper_only?).to be_truthy
      end
    end

    it "with two subscriptions, the first a current digital, the second an expired paper only, has the correct expiry date and paper expiry date" do
      subscription.duration = 12
      subscription.save
      user.subscriptions.new(valid_from: DateTime.now - 18.months, duration: 12, purchase_date: DateTime.now - 18.months, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        expect(user.subscriptions.count).to eq(2)
        expect(user.subscriptions.first.purchase_date + (user.subscriptions.first.duration).months).to eq(user.expiry_date)
        expect(user.subscriptions.last.purchase_date + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_only)
        expect(user.subscriptions.last.valid_from + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_copy)
        expect(user.has_paper_copy?).to be_falsey
        expect(user.has_paper_only?).to be_falsey
      end
    end

    it "with three subscriptions, expired digital, expired paper only, new paper_only, has the correct expiry date and paper expiry date" do
      # Expired digital
      subscription.duration = 12
      subscription.valid_from = DateTime.now - 18.months
      subscription.purchase_date = DateTime.now - 18.months
      subscription.save
      # Expired paper only
      user.subscriptions.new(valid_from: DateTime.now - 24.months, duration: 12, purchase_date: DateTime.now - 24.months, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      # New paper only
      user.subscriptions.new(valid_from: DateTime.now, duration: 12, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        expect(user.subscriptions.count).to eq(3)
        expect(user.subscriptions.last.purchase_date + 3.months).to eq(user.expiry_date)
        expect(user.subscriptions.last.purchase_date + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_only)
        expect(user.subscriptions.last.valid_from + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_copy)
        expect(user.has_paper_copy?).to be_truthy
        expect(user.has_paper_only?).to be_truthy
      end
    end

    it "with three subscriptions, expired digital, expired paper only, new paper and digital, has the correct expiry date and paper expiry date" do
      # Expired digital
      subscription.duration = 12
      subscription.valid_from = DateTime.now - 18.months
      subscription.purchase_date = DateTime.now - 18.months
      subscription.save
      # Expired paper only
      user.subscriptions.new(valid_from: DateTime.now - 24.months, duration: 12, purchase_date: DateTime.now - 24.months, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      # New paper and digital
      user.subscriptions.new(valid_from: DateTime.now, duration: 6, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        expect(user.subscriptions.count).to eq(3)
        expect(user.subscriptions.last.purchase_date + (user.subscriptions.last.duration).months).to eq(user.expiry_date)
        expect(user.subscriptions.second.purchase_date + (user.subscriptions.second.duration).months).to eq(user.expiry_date_paper_only)
        expect(user.subscriptions.last.valid_from + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_copy)
        expect(user.has_paper_copy?).to be_truthy
        expect(user.has_paper_only?).to be_falsey
      end
    end

    it "with three subscriptions, current digital, expired paper only, new paper only, has the correct expiry date and paper expiry date" do
      # Current digital
      subscription.duration = 12
      subscription.valid_from = DateTime.now
      subscription.purchase_date = DateTime.now
      subscription.save
      # Expired paper only
      user.subscriptions.new(valid_from: DateTime.now - 24.months, duration: 12, purchase_date: DateTime.now - 24.months, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      # New paper only
      user.subscriptions.new(valid_from: DateTime.now, duration: 6, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        expect(user.subscriptions.count).to eq(3)
        expect(user.subscriptions.first.purchase_date + (user.subscriptions.first.duration).months).to eq(user.expiry_date)
        expect(user.subscriptions.last.purchase_date + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_only)
        expect(user.subscriptions.last.valid_from + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_copy)
        expect(user.has_paper_copy?).to be_truthy
        expect(user.has_paper_only?).to be_truthy
      end
    end

    it "with three subscriptions, current digital, expired paper only, new paper only, has the correct expiry date and paper expiry date" do
      # Current digital
      subscription.duration = 12
      subscription.valid_from = DateTime.now
      subscription.purchase_date = DateTime.now
      subscription.save
      # Expired paper only
      user.subscriptions.new(valid_from: DateTime.now - 24.months, duration: 12, purchase_date: DateTime.now - 24.months, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      # New paper and digital
      user.subscriptions.new(valid_from: DateTime.now, duration: 6, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        expect(user.subscriptions.count).to eq(3)
        expect(user.subscriptions.first.purchase_date + (user.subscriptions.first.duration).months).to eq(user.expiry_date)
        # TODO: Should add the first digital current sub with the last digital and paper duration
        # expect((user.subscriptions.first.purchase_date + (user.subscriptions.first.duration).months) + (user.subscriptions.last.duration).months).to eq(user.expiry_date)
        expect(user.subscriptions.second.purchase_date + (user.subscriptions.second.duration).months).to eq(user.expiry_date_paper_only)
        expect(user.subscriptions.last.valid_from + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_copy)
        expect(user.has_paper_copy?).to be_truthy
        expect(user.has_paper_only?).to be_falsey
      end
    end

    it "with three subscriptions, expired digital, current paper only, new paper only, has the correct expiry date and paper expiry date" do
      # Expired digital
      subscription.duration = 12
      subscription.valid_from = DateTime.now - 18.months
      subscription.purchase_date = DateTime.now - 18.months
      subscription.save
      # Current paper only
      user.subscriptions.new(valid_from: DateTime.now, duration: 12, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      # New paper only
      user.subscriptions.new(valid_from: user.subscriptions.second.expiry_date_paper_only, duration: 6, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        expect(user.subscriptions.count).to eq(3)
        expect(user.subscriptions.last.valid_from + 3.months).to eq(user.expiry_date)
        expect(user.subscriptions.last.valid_from + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_only)
        expect(user.subscriptions.last.valid_from + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_copy)
        expect(user.has_paper_copy?).to be_truthy
        expect(user.has_paper_only?).to be_truthy
      end
    end

    it "with three subscriptions, expired digital, current paper only, new paper and digital, has the correct expiry date and paper expiry date" do
      # Expired digital
      subscription.duration = 12
      subscription.valid_from = DateTime.now - 18.months
      subscription.purchase_date = DateTime.now - 18.months
      subscription.save
      # Current paper only
      user.subscriptions.new(valid_from: DateTime.now, duration: 12, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1, paper_only: 1)
      user.subscriptions.last.save
      # New paper and digital
      user.subscriptions.new(valid_from: user.subscriptions.second.expiry_date_paper_only, duration: 6, purchase_date: DateTime.now, paypal_payer_id: "aaa", paypal_profile_id: "bbb", price_paid: 91, paper_copy: 1)
      user.subscriptions.last.save
      Timecop.freeze(2012,1,10,0,0,0) do
        expect(user.subscriptions.count).to eq(3)
        expect(user.subscriptions.last.valid_from + (user.subscriptions.last.duration).months).to eq(user.expiry_date)
        expect(user.subscriptions.second.valid_from + (user.subscriptions.second.duration).months).to eq(user.expiry_date_paper_only)
        expect(user.subscriptions.last.valid_from + (user.subscriptions.last.duration).months).to eq(user.expiry_date_paper_copy)
        expect(user.has_paper_copy?).to be_truthy
        expect(user.has_paper_only?).to be_truthy
      end
    end

  end

  context "manager" do

    let(:user) do
      FactoryBot.create(:manager_user)
    end

    let(:ability) { Ability.new(user) }

    it "should be able to read an article" do
      article = FactoryBot.create(:article)
      expect(ability).to be_able_to(:read, article)
    end

    it "should not be able to manage an article" do
      article = FactoryBot.create(:article)
      expect(ability).not_to be_able_to(:manage, article)
    end

    it "should not be able to manage a page" do
      page = FactoryBot.create(:page)
      expect(ability).not_to be_able_to(:manage, page)
    end

    it "should not be able to manage settings" do
      settings = Settings.get_all
      expect(ability).not_to be_able_to(:manage, settings)
    end

    it "should not be able to manage a push registration" do
      push_registration = FactoryBot.create(:push_registration)
      expect(ability).not_to be_able_to(:manage, push_registration)
    end

    it "should not be able to manage a payment notifications" do
      payment_notification = FactoryBot.create(:payment_notification)
      expect(ability).not_to be_able_to(:manage, payment_notification)
    end

    it "should be able to manage a user" do
      general_user = FactoryBot.create(:user)
      expect(ability).to be_able_to(:manage, general_user)
    end

    it "should be able to manage a subscription" do
      subscription = FactoryBot.create(:subscription)
      expect(ability).to be_able_to(:manage, subscription)
    end

  end

end

