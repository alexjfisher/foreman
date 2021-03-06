require 'test_helper'

class RegistrationCommandsControllerTest < ActionController::TestCase
  describe 'create' do
    test 'with params' do
      params = {
        organizationId: taxonomies(:organization1).id,
        locationId: taxonomies(:location1).id,
        hostgroupId: hostgroups(:common).id,
        operatingsystemId: operatingsystems(:redhat).id,
      }
      post :create, params: params, session: set_session_user
      command = JSON.parse(@response.body)['command']

      assert_includes command, 'organizationId='
      assert_includes command, 'locationId='
      assert_includes command, 'hostgroupId='
      assert_includes command, 'operatingsystemId='
    end

    test 'with params ignored in URL' do
      params = {
        smart_proxy_id: smart_proxies(:one).id,
        insecure: true,
        jwt_expiration: 23,
      }

      post :create, params: params, session: set_session_user
      command = JSON.parse(@response.body)['command']

      assert_includes command, "curl -sS --insecure '#{smart_proxies(:one).url}/register"
      refute command.include?('smart_proxy_id')
      refute command.include?('insecure=true')
      refute command.include?('jwt_expiration')
    end

    context 'host_params' do
      let(:params) { { organization: taxonomies(:organization1).id, location: taxonomies(:location1).id } }

      before do
        CommonParameter.where(name: 'host_registration_insights').destroy_all
        CommonParameter.where(name: 'setup_remote_execution').destroy_all
      end

      test 'inherit value' do
        post :create, params: params, session: set_session_user

        refute JSON.parse(@response.body)['command'].include?('setup_insights')
        refute JSON.parse(@response.body)['command'].include?('setup_remote_execution')
      end

      test 'yes (override)' do
        post :create, params: params.merge(setup_insights: true, setup_remote_execution: true), session: set_session_user

        assert JSON.parse(@response.body)['command'].include?('setup_insights=true')
        assert JSON.parse(@response.body)['command'].include?('setup_remote_execution=true')
      end

      test 'no (override)' do
        post :create, params: params.merge(setup_insights: false, setup_remote_execution: false), session: set_session_user

        assert JSON.parse(@response.body)['command'].include?('setup_insights=false')
        assert JSON.parse(@response.body)['command'].include?('setup_remote_execution=false')
      end
    end

    context 'jwt' do
      test 'with default expiration' do
        post :create, session: set_session_user
        command = JSON.parse(@response.body)['command']
        parsed_token = command.scan(/(?<=Bearer )(.*)(?=.*)(?=\')/).flatten[0]
        assert JwtToken.new(parsed_token).decode['exp']
      end

      test 'with expiration' do
        post :create, params: { jwt_expiration: 23 }, session: set_session_user
        command = JSON.parse(@response.body)['command']
        parsed_token = command.scan(/(?<=Bearer )(.*)(?=.*)(?=\')/).flatten[0]
        assert JwtToken.new(parsed_token).decode['exp']
      end

      test 'unlimited' do
        post :create, params: { jwt_expiration: 'unlimited' }, session: set_session_user
        command = JSON.parse(@response.body)['command']
        parsed_token = command.scan(/(?<=Bearer )(.*)(?=.*)(?=\')/).flatten[0]

        refute JwtToken.new(parsed_token).decode['exp']
      end
    end
  end
end
