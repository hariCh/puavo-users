Feature: Manage profile
  In order to [goal]
  [stakeholder]
  wants [behaviour]

  Background:
    Given a new school and group with names "School 1", "Class 4" on the "example" organisation
    And a new role with name "Class 4" and which is joined to the "Class 4" group
    And the following roles:
      | displayName |
      | Teacher     |
    And the following users:
      | givenName | surname | uid       | password | puavoEduPersonAffiliation | role_name | school_admin |
      | Ken       | Jones   | ken.jones | secret   | teacher                   | Teacher   | true         |


  Scenario: School admin edit profile
    When I am on the edit profile page
    Then I should be on the login page
    When I fill in "Username" with "ken.jones"
    And I fill in "Password" with "secret"
    And I press "Login"
    Then I should see "Login successful!"
    And I should see "Ken Jones"
    When I fill in "Email" with "ken.jones@opinsys.fi"
    And I fill in "Telephone number" with "+35814123456789"
    # FIXME: select field?
    # And I fill in "preferredLanguage" with "fi"
    # FIXME image field?
    # And I fill in "image" with ""
    # FIXME: use password controller?
    # And I fill in "password" with ""

    # FIXME image field?
    # And I fill in "background" with ""
    # FIXME following fields should be add to ldap
    # And I fill in "theme" with ""
    # And I fill in "mouse?" with ""

    When I press "Update"
    Then I should see "Profile was successfully updated"