require_relative "../lib/ldappasswd"

module PuavoRest

class User < LdapModel

  ldap_map :dn, :dn
  ldap_map :puavoId, :id
  ldap_map :uid, :username
  ldap_map(:uidNumber, :uid_number){ |v| Array(v).first.to_i }
  ldap_map(:gidNumber, :gid_number){ |v| Array(v).first.to_i }
  ldap_map :sn, :last_name
  ldap_map :givenName, :first_name
  ldap_map :mail, :email
  ldap_map( :mail, :secondary_emails){ |v| _, *other_emails = Array(v); other_emails }
  ldap_map(:puavoSchool, :school_dns){ |v| Array(v) }
  ldap_map :preferredLanguage, :preferred_language
  ldap_map(:jpegPhoto, :profile_image_link) do |image_data|
    if image_data
      @model.link "/v3/users/#{ @model.username }/profile.jpg"
    end
  end
  ldap_map :puavoLocale, :locale
  ldap_map :puavoTimezone, :timezone
  ldap_map :puavoLocked, :locked, &LdapConverters.string_boolean
  ldap_map :puavoSshPublicKey, :ssh_public_key

  # The classic Roles in puavo-web are now deprecated.
  # puavoEduPersonAffiliation will used as the roles from now on
  ldap_map(:puavoEduPersonAffiliation, :roles){ |v| Array(v) }

  # Roles does not make much sense without a school
  skip_serialize :roles

  # List of school DNs where the user is school admin
  ldap_map(:puavoAdminOfSchool, :admin_of_school_dns) do |dns|
    Array(dns).map do |dn|
      dn.downcase
    end
  end

  def is_school_admin_in?(school)
    admin_of_school_dns.include?(school.dn.downcase)
  end

  def roles_within_school(school)
    _roles = roles
    if is_school_admin_in?(school)
      _roles.push("schooladmin")
    end
    _roles
  end

  # XXX: deprecated!
  computed_attr :user_type
  def user_type
    roles.first
  end

  computed_attr :puavo_id
  def puavo_id
    id
  end

  computed_attr :unique_id
  def unique_id
    dn.downcase
  end

  def self.ldap_base
    "ou=People,#{ organisation["base"] }"
  end

  # aka by_uuid
  def self.by_username(username, attrs=nil)
    by_attr(:username, username, :single, attrs)
  end

  def self.resolve_dn(username)
    dn = raw_filter("(uid=#{ escape username })", ["dn"])
    if dn && !dn.empty?
      dn.first["dn"].first
    end
  end

  def self.profile_image(uid)
    data = raw_filter("(uid=#{ escape uid })", ["jpegPhoto"])
    if !data || data.size == 0
      raise NotFound, :user => "Cannot find image data for user: #{ uid }"
    end

    data.first["jpegPhoto"]
  end

  def organisation
    User.organisation
  end

  computed_attr :organisation_domain
  def organisation_domain
    organisation.domain
  end

  computed_attr :organisation_name
  def organisation_name
    organisation.name
  end

  computed_attr :school_dn
  def school_dn
    Array(school_dns).first
  end

  # Primary school
  def school
    return @school if @school
    return if school_dn.nil?
    @school = School.by_dn(school_dn)
  end

  computed_attr :primary_school_id
  def primary_school_id
    school.id if school
  end

  def schools
    # TODO: handle errors
    @schools ||= school_dns.map do |dn|
      School.by_dn(dn)
    end.compact
  end

  def preferred_language
    if get_own(:preferred_language).nil? && school
      school.preferred_language
    else
      get_own(:preferred_language)
    end
  end

  def locale
    if get_own(:locale).nil? && school
      school.locale
    else
      get_own(:locale)
    end
  end

  def timezone
    if get_own(:timezone).nil? && school
      school.timezone
    else
      get_own(:timezone)
    end
  end

  def admin?
    user_type == "admin"
  end

  def groups
    @groups ||= Group.by_user_dn(dn)
  end

  def groups_within_school(school)
    groups.select do |group|
        group.school_id == school.id
    end
  end

  computed_attr :domain_username
  def domain_username
    "#{ username }@#{ organisation.domain }"
  end

  computed_attr :homepage
  def homepage
    if school
      school.homepage
    end
  end

  def server_user?
    dn == CONFIG["server"][:dn]
  end

  computed_attr :schools_hash, :schools
  def schools_hash
    schools.map do |school|
        {
          "id" => school.id,
          "dn" => school.dn,
          "name" => school.name,
          "abbreviation" => school.abbreviation,
          "roles" => roles_within_school(school),
          "groups" => groups_within_school(school).map do |group|
            {
              "id" => group.id,
              "dn" => group.dn,
              "name" => group.name,
              "abbreviation" => group.abbreviation
            }
          end
        }
    end
  end

  def self.current
    return settings[:credentials_cache][:current_user] if settings[:credentials_cache][:current_user]

    user_credentials = settings[:credentials]

    if user_credentials[:dn]
      user = User.by_dn(user_credentials[:dn])
    elsif user_credentials[:username]
      user = User.by_username(user_credentials[:username])
    end

    settings[:credentials_cache][:current_user] = user
  end

  def self.search_filters
    [
      create_filter_lambda(:username),
      create_filter_lambda(:first_name),
      create_filter_lambda(:last_name),
      create_filter_lambda(:email)
    ]
  end

end

class Users < LdapSinatra
  DIR = File.expand_path(File.dirname(__FILE__))
  ANONYMOUS_IMAGE_PATH = DIR + "/anonymous.png"


  get "/v3/users/_search" do
    auth :basic_auth, :kerberos
    json User.search(params["q"])
  end

  # Return users in a organisation
  get "/v3/users" do
    auth :basic_auth, :kerberos

    # XXX cannot combine filters
    if params["email"]
      json User.by_attr(:email, params["email"], :multi, params["attributes"])
    elsif params["id"]
      json User.by_attr(:id, params["id"], :multi, params["attributes"])
    else
      users = User.all(params["attributes"])
      json users
    end

  end

  # Return users in a organisation
  get "/v3/users/:username" do
    auth :basic_auth, :kerberos

    json User.by_username(params["username"], params["attributes"])
  end

  get "/v3/users/:username/profile.jpg" do
    auth :basic_auth, :kerberos
    content_type "image/jpeg"

    image = User.profile_image(params["username"])
    if image
      image
    else
      File.open(ANONYMOUS_IMAGE_PATH, "r") { |f| f.read }
    end
  end

  get "/v3/whoami" do
    auth :basic_auth, :kerberos
    user = User.current.to_hash
    json user.merge("organisation" => LdapModel.organisation.to_hash)
  end

end
end

