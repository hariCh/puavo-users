
require_relative "./helper"

module School_test
describe PuavoRest::School do


  before(:each) do
    Timecop.travel(Fixtures::ICS_TIME)
    Puavo::Test.clean_up_ldap
    PuavoRest::Session.local_store.flushdb
    FileUtils.rm_rf CONFIG["ltsp_server_data_dir"]
    @school = School.create(
      :cn => "gryffindor",
      :displayName => "Gryffindor",
      :preferredLanguage => "school-lang",
      :puavoSchoolHomePageURL => "gryffindor.example"
    )

    @school.external_feeds = "http://cal.example.com/cal.ics"
    @school.save!

    LdapModel.setup(
      :organisation =>
        PuavoRest::Organisation.default_organisation_domain!,
      :rest_root => "http://" + CONFIG["default_organisation_domain"],
                    :credentials => { :dn => PUAVO_ETC.ldap_dn, :password => PUAVO_ETC.ldap_password }
    )

  end

  after(:each) do
    Timecop.return
  end

  it "has external_feeds" do
    school = PuavoRest::School.by_dn!(@school.dn)
    assert school.external_feeds
    assert_equal(
      [
        {
          "type"=>"ical",
         "name"=>"Opinsys",
         "value"=>"http://cal.example.com/cal.ics"
        }
      ],
      school.external_feeds
    )
  end

  it "has empty message before caching" do
    school = PuavoRest::School.by_dn!(@school.dn)
    assert_equal([], school.messages)
  end

  it "has messages after cache is populated" do
    school = PuavoRest::School.by_dn!(@school.dn)

    stub_request(:get, "http://cal.example.com/cal.ics").
      to_return(:body => File.new(Fixtures::ICS_FILE), :status => 200)

    school.cache_feeds()

    assert_equal(2, school.messages.size, school.messages)
    assert_equal(
      [
        {"message"=>"long event"},
        {"message"=>"event of today"}
      ],
      school.messages)
  end

  it "bad url does not interfere" do
    @school.external_feeds = ["http://cal.example.com/cal.ics", "bad"]
    @school.save!

    school = PuavoRest::School.by_dn!(@school.dn)

    stub_request(:get, "http://cal.example.com/cal.ics").
      to_return(:body => File.new(Fixtures::ICS_FILE), :status => 200)

    school.cache_feeds()

    assert_equal(2, school.messages.size, school.messages)
    assert_equal(
      [
        {"message"=>"long event"},
        {"message"=>"event of today"}
      ],
      school.messages)
  end

end
end