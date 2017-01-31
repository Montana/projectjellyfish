class RemoteAuthSession
  class Create < ApplicationService
    include Model
    include Sanitize
    include Validation

    model User, :find

    sanitize do
      required(:user_agent, :string).filled
      required(:remote_ip, :string).filled
      required(:remote_user, User::Types::EMAIL).filled(format?: User::Types::EMAIL_REGEXP)
      required(:name, :string).filled
    end

    validation do
      required(:user_agent, :string).filled
      required(:remote_ip, :string).filled
      required(:remote_user, User::Types::EMAIL).filled(format?: User::Types::EMAIL_REGEXP)
      required(:name, :string).filled

      # We activated new accounts, but have to check existing accounts
      validate active?: [:email] do
        model.active?
      end
    end

    def perform
      validate do
        model.last_login_at = DateTime.current
        model.last_client_info = login_info
        model.regenerate_session_token # Saves the user record
      end
    end

    def find_model!
      User.find_or_create_by!(email: params[:remote_user]) do |user|
        user.name = params[:name]
        # adding a random password since the user model requires a password
        user.password = user.password_confirmation = SecureRandom.base64(12)
        # Bypassing state machine activation actions and marking user as active
        user.state = 'active'
      end
    rescue
      raise Goby::Exceptions::ValidationErrors.new data: { attributes: ['Could not authenticate user'] }
    end

    def login_info
      "#{params[:remote_ip]} #{params[:user_agent]}"
    end
  end
end
