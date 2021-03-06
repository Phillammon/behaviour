#
# Copyright (C) 2021 Grakn Labs
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

#noinspection CucumberUndefinedStep
Feature: Resolution Test Framework

  Background: Set up databases for resolution testing

    Given connection has been opened
    Given connection open sessions for databases:
      | materialised |
      | reasoned     |




  Scenario: basic rule
    Given for each session, graql define
      """
      define

      name sub attribute, value string;

      company sub entity,
        owns name;

      rule company-has-name: when {
         $c isa company;
      } then {
         $c has name "the-company";
      };
      """
    Given for each session, graql insert
      """
      insert
      $x isa company;
      """
    Then materialised database is completed
    Given for each session, transaction commits
    Given for each session, open transactions with reasoning of type: read
    Then for graql query
      """
      match $co has name $n;
      """
    Then all answers are correct in reasoned database
    Then materialised and reasoned databases are the same size


  Scenario: compounding rules
    Given for each session, graql define
      """
      define

      name sub attribute,
          value string;

      is-liable sub attribute,
          value boolean;

      company sub entity,
          owns name,
          owns is-liable;

      rule company-has-name: when {
          $c1 isa company;
      } then {
          $c1 has name "the-company";
      };

      rule company-is-liable: when {
          $c2 isa company, has name $name; $name "the-company";
      } then {
          $c2 has is-liable true;
      };
      """
    Given for each session, graql insert
      """
      insert
      $co isa company;
      """

    Then materialised database is completed
    Given for each session, transaction commits
    Given for each session, open transactions with reasoning of type: read
    Then for graql query
      """
      match $co has is-liable $l;
      """
    Then all answers are correct in reasoned database
    Then materialised and reasoned databases are the same size


  Scenario: 2-hop transitivity
    Given for each session, graql define
      """
      define
      name sub attribute, value string;

      location-hierarchy-id sub attribute, value long;

      location sub entity,
          abstract,
          owns name,
          plays location-hierarchy:superior,
          plays location-hierarchy:subordinate;

      area sub location;
      city sub location;
      country sub location;

      location-hierarchy sub relation,
          relates superior,
          relates subordinate;

      rule location-hierarchy-transitivity: when {
          (superior: $a, subordinate: $b) isa location-hierarchy;
          (superior: $b, subordinate: $c) isa location-hierarchy;
      } then {
          (superior: $a, subordinate: $c) isa location-hierarchy;
      };
      """
    Given for each session, graql insert
      """
      insert
      $ar isa area, has name "King's Cross";
      $cit isa city, has name "London";
      $cntry isa country, has name "UK";
      (superior: $cntry, subordinate: $cit) isa location-hierarchy;
      (superior: $cit, subordinate: $ar) isa location-hierarchy;
      """

    Then materialised database is completed
    Given for each session, transaction commits
    Given for each session, open transactions with reasoning of type: read
    Then for graql query
      """
      match
      $k isa entity, has name "King's Cross";
      (superior: $l, subordinate: $k) isa location-hierarchy;
      """
    Then all answers are correct in reasoned database
    Then materialised and reasoned databases are the same size


  @ignore
  # TODO: currently this scenario takes longer than 2 hours to execute (#75) - re-enable when fixed
  Scenario: 3-hop transitivity
    Given for each session, graql define
      """
      define
      name sub attribute,
      value string;

      location-hierarchy-id sub attribute,
          value long;

      location sub entity,
          abstract,
          owns name,
          plays location-hierarchy_superior,
          plays location-hierarchy_subordinate;

      area sub location;
      city sub location;
      country sub location;
      continent sub location;

      location-hierarchy sub relation,
          relates location-hierarchy_superior,
          relates location-hierarchy_subordinate;

      rule location-hierarchy-transitivity: when {
          (location-hierarchy_superior: $a, location-hierarchy_subordinate: $b) isa location-hierarchy;
          (location-hierarchy_superior: $b, location-hierarchy_subordinate: $c) isa location-hierarchy;
      } then {
          (location-hierarchy_superior: $a, location-hierarchy_subordinate: $c) isa location-hierarchy;
      };
      """
    Given for each session, graql insert
      """
      insert
      $ar isa area, has name "King's Cross";
      $cit isa city, has name "London";
      $cntry isa country, has name "UK";
      $cont isa continent, has name "Europe";
      (location-hierarchy_superior: $cont, location-hierarchy_subordinate: $cntry) isa location-hierarchy;
      (location-hierarchy_superior: $cntry, location-hierarchy_subordinate: $cit) isa location-hierarchy;
      (location-hierarchy_superior: $cit, location-hierarchy_subordinate: $ar) isa location-hierarchy;
      """

    Then materialised database is completed
    Given for each session, transaction commits
    Given for each session, open transactions with reasoning of type: read
    Then for graql query
      """
      match $lh (location-hierarchy_superior: $continent, location-hierarchy_subordinate: $area) isa location-hierarchy;
      $continent isa continent; $area isa area;
      """
    Then all answers are correct in reasoned database
    Then materialised and reasoned databases are the same size


  Scenario: queried relation is a supertype of the inferred relation
    Given for each session, graql define
      """
      define

      name sub attribute, value string;

      person sub entity,
          owns name,
          plays siblingship:sibling;

      man sub person;
      woman sub person;

      family-relation sub relation,
        abstract;

      siblingship sub family-relation,
          relates sibling;

      rule a-man-is-called-bob: when {
          $man isa man;
      } then {
          $man has name "Bob";
      };

      rule bobs-sister-is-alice: when {
          $p isa man, has name $nb; $nb "Bob";
          $p1 isa woman, has name $na; $na "Alice";
      } then {
          (sibling: $p, sibling: $p1) isa siblingship;
      };
      """
    Given for each session, graql insert
      """
      insert
      $a isa woman, has name "Alice";
      $b isa man;
      """

    Then materialised database is completed
    Given for each session, transaction commits
    Given for each session, open transactions with reasoning of type: read
    Then for graql query
      """
      match ($w, $m) isa family-relation; $w isa woman;
      """
    Then all answers are correct in reasoned database
    Then materialised and reasoned databases are the same size


  @ignore
  Scenario: querying with a disjunction and a negation
    Given for each session, graql define
      """
      define

      name sub attribute,
          value string;

      is-liable sub attribute,
          value boolean;

      company sub entity,
          owns name,
          owns is-liable;

      rule company-is-liable: when {
          $c2 isa company, has name $n2; $n2 "the-company";
      } then {
          $c2 has is-liable true;
      };
      """
    Given for each session, graql insert
      """
      insert
      $c1 isa company;
      $c1 has name $n1; $n1 "the-company";
      $c2 isa company;
      $c2 has name $n2; $n2 "another-company";
      """

    Then materialised database is completed
    Given for each session, transaction commits
    Given for each session, open transactions with reasoning of type: read
    Then for graql query
      """
      match $com isa company;
      {$com has name $n1; $n1 "the-company";} or {$com has name $n2; $n2 "another-company";};
      not {$com has is-liable $liability;};
      """
    Then all answers are correct in reasoned database
    Then materialised and reasoned databases are the same size


  Scenario: a rule containing a negation
    Given for each session, graql define
      """
      define

      name sub attribute,
          value string;

      is-liable sub attribute,
          value boolean;

      company sub entity,
          owns name,
          owns is-liable;

      rule company-is-liable: when {
          $c2 isa company;
          not {
            $c2 has name $n2; $n2 "the-company";
          };
      } then {
          $c2 has is-liable true;
      };
      """
    Given for each session, graql insert
      """
      insert
      $c1 isa company;
      $c1 has name $n1; $n1 "the-company";
      $c2 isa company;
      $c2 has name $n2; $n2 "another-company";
      """

    Then materialised database is completed
    Given for each session, transaction commits
    Given for each session, open transactions with reasoning of type: read
    Then for graql query
      """
      match $com isa company, has is-liable $lia; $lia true;
      """
    Then all answers are correct in reasoned database
    Then materialised and reasoned databases are the same size


  Scenario: querying with multiple negations
    Given for each session, graql define
      """
      define

      name sub attribute,
          value string;

      is-liable sub attribute,
          value boolean;

      company sub entity,
          owns name,
          owns is-liable;

      rule company-is-liable: when {
          $c2 isa company;
          $c2 has name $n2; $n2 "the-company";
      } then {
          $c2 has is-liable true;
      };
      """
    Given for each session, graql insert
      """
      insert
      $c1 isa company;
      $c1 has name $n1; $n1 "the-company";
      $c2 isa company;
      $c2 has name $n2; $n2 "another-company";
      """

    Then materialised database is completed
    Given for each session, transaction commits
    Given for each session, open transactions with reasoning of type: read
    Then for graql query
      """
      match $com isa company; not { $com has is-liable $lia; $lia true; }; not { $com has name $n; $n "the-company"; };
      """
    Then all answers are correct in reasoned database
    Then materialised and reasoned databases are the same size
