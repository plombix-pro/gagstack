class UserMailer < ApplicationMailer
  def verification(user)
    @user = user
    @verification_url = verify_email_url(token: user.verification_token)
    mail to: user.email_address, subject: "Verify your GagStack account"
  end

  def email_change(user)
    @user = user
    @confirmation_url = verify_email_change_url(token: user.email_change_token)
    mail to: user.unconfirmed_email, subject: "Confirm your new email address"
  end
end
