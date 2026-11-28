# A profile as the picker and the client see it. The password digest never leaves the API.
class ProfilePresenter
  def initialize(profile)
    @profile = profile
  end

  def as_json(*)
    {
      id: @profile.id,
      name: @profile.name,
      color_code: @profile.color_code,
      locale: @profile.locale,
      password_protected: @profile.password_protected?
    }
  end
end
