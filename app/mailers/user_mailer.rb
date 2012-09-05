class UserMailer < ActionMailer::Base
  # default from: "subscribe@newint.com.au"
  # TODO: set this to subscribe@newint.com.au for production
  default :from => "newint.au@gmail.com"

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.subscription_confirmation.subject
  #
  def subscription_confirmation(user)
    @user = user
    @greeting = "Hi"
    mail(:to => user.email, :bcc => "design@newint.com.au", :subject => "New Internationalist Digital Subscription")
  end

  def subscription_cancellation(user)
    @user = user
    @greeting = "Hi"
    mail(:to => user.email, :bcc => "design@newint.com.au", :subject => "Cancelled New Internationalist Digital Subscription")
  end

  def issue_purchase(user, issue)
    @user = user
    @issue = issue
    @greeting = "Hi"
    mail(:to => user.email, :bcc => "design@newint.com.au", :subject => "New Internationalist Digital Issue")
  end
end