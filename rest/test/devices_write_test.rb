require_relative "./helper"

describe PuavoRest::Devices do

  before(:each) do
    Puavo::Test.clean_up_ldap
    FileUtils.rm_rf CONFIG["ltsp_server_data_dir"]
    @school = School.create(
      :cn => "gryffindor",
      :displayName => "Gryffindor",
      :puavoDeviceImage => "schoolprefimage",
      :puavoPersonalDevice => true,
      :puavoSchoolHomePageURL => "schoolhomepagefordevice.example",
      :puavoAllowGuest => true,
      :puavoAutomaticImageUpdates => true,
      :puavoImageSeriesSourceURL => "https://foobar.opinsys.fi/schoolpref.json",
      :puavoLocale => "fi_FI.UTF-8",
      :puavoTag => ["schooltag"],
      :puavoMountpoint => [ '{"fs":"nfs3","path":"10.0.0.3/share","mountpoint":"/home/school/share","options":"-o r"}',
                            '{"fs":"nfs4","path":"10.5.5.3/share","mountpoint":"/home/school/public","options":"-o r"}' ]
    )

    @laptop = create_device(
      :puavoHostname => "laptop1",
      :puavoDeviceType =>  "laptop",
      :macAddress => "00:60:2f:28:DC:51",
      :puavoSchool => @school.dn
    )
    @laptop.save!

  end

  describe "device information" do

    it "bloo"  do
      get "/v3/devices/laptop1"
      assert_200
      @data = JSON.parse last_response.body
    end
  end
end
