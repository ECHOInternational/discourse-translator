require 'rails_helper'

RSpec.describe ::DiscourseTranslator::TranslatorController do
  routes { ::DiscourseTranslator::Engine.routes }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator = 'Microsoft'
  end

  after do
    SiteSetting.translator_enabled = false
  end

  describe "#translate" do
    describe 'anon user' do
      it 'should not allow translation of posts' do
        post :translate, params: { post_id: 1 }, format: :json
        expect(response.status).to eq(403)
      end
    end

    describe 'logged in user' do
      let!(:user) { log_in }

      describe "when disabled" do
        before { SiteSetting.translator_enabled = false }

        it 'should deny request to translate' do
          response = post :translate, params: { post_id: 1 }, format: :json

          expect(response.status).to eq(404)
        end
      end

      describe "when enabled" do
        let(:reply) { Fabricate(:post) }

        it 'raises an error with a missing parameter' do
          post :translate, format: :json
          expect(response.status).to eq(400)
        end

        it 'raises the right error when post_id is invalid' do
          post :translate, params: { post_id: -1 }, format: :json
          expect(response.status).to eq(400)
        end

        it 'rescues translator errors' do
          DiscourseTranslator::Microsoft.expects(:translate).raises(::DiscourseTranslator::TranslatorError)

          post :translate, params: { post_id: reply.id }, format: :json

          expect(response).to have_http_status(422)
        end

        it 'returns the translated text' do
          DiscourseTranslator::Microsoft.expects(:translate).with(reply).returns(['ja', 'ニャン猫'])

          post :translate, params: { post_id: reply.id }, format: :json

          expect(response).to be_successful
          expect(response.body).to eq({ translation: 'ニャン猫', detected_lang: 'ja' }.to_json)
        end
      end
    end
  end
end
