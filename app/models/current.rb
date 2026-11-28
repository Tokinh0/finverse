# The profile (and its session) the current request or job works for. Every ProfileOwned model
# is scoped to Current.profile, so set it before touching data outside a request:
#
#   Current.profile = Profile.find_by(name: "...")            # console
#   Current.set(profile: profile) { ... }                      # jobs, tasks, seeds
class Current < ActiveSupport::CurrentAttributes
  attribute :profile, :session

  def account
    profile&.account
  end
end
