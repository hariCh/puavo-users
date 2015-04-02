require_relative "./helper"
require_relative "../lib/ldapmodel"

describe LdapModel do

  describe "attribute writing" do

    class WriteableLM < LdapModel
      ldap_map :fooBar, :foo_bar

      ldap_map :jsonValue, :json_value

      def json_value
        JSON.parse(get_own(:json_value)) if get_own(:json_value)
      end

      def json_value=(value)
        write_own(:json_value, value.to_json)
      end

    end

    it "should convert attributes according ldap_map" do
      h = WriteableLM.from_ldap_hash({
        "fooBar" => "bar"
      })

      assert_equal "bar", h.foo_bar
      h.foo_bar = "foo"
      assert_equal "foo", h.foo_bar

    end

    it "can use custom getters and setters" do
      h = WriteableLM.from_ldap_hash({
        "jsonValue" => '{"lol": "haha"}'
      })

      assert_equal "haha", h.json_value["lol"]

      h.json_value = {"lol" => "buhaha"}
      assert_equal "buhaha", h.json_value["lol"]

    end

  end

end
