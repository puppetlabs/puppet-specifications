import 'facts_db.pp'

example 'mongodb::db' {
  example 'default' {
    $facts_db.each { |$loop_facts|
      given 'default' (
        $facts = $loop_facts,
        $modules = $default_modules,
      ) {
        mongodb::db { 'testdb' :
          user => 'testuser',
          password => 'testpass',
        }
      }
      assert 'it contains mongodb_database with mongodb::server requirement' {
        mongodb_database { 'testdb' : }
      }
      assert 'it contains mongodb_user with mongodb_database requirement' {
        mongodb_user { 'User testuser on db testdb' :
          username => 'testuser',
          database => 'testdb',
          require => Mongodb_database['testdb'],
        }
      }
    }
  }
  example 'old modules' {
    given 'default' (
      $facts   = {}
      $modules = {'puppetlabs-stdlib' => '4.4.0', }.merge($default_modules),
    ) {
      mongodb::db { 'testdb' :
        user => 'testuser',
        password => 'testpass',
      }
    }
    assert {
      # it compiles, at least
    }
  }
}
