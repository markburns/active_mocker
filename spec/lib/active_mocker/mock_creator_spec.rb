require 'spec_helper'
require 'lib/post_methods'
require 'active_support/core_ext/string'
require 'spec/support/strip_heredoc'
require 'active_mocker/error_object'
require 'active_mocker/hash_new_style'
require 'active_mocker/parent_class'
require 'active_mocker/template_creator'
require 'active_mocker/mock_creator'
require 'active_record_schema_scrapper'
require 'dissociated_introspection'
require 'reverse_parameters'
require 'tempfile'

describe ActiveMocker::MockCreator do

  before do
    stub_const("ActiveRecord::Base", active_record_stub_class)
  end

  let(:active_record_stub_class) { Class.new }

  def format_code(code)
    DissociatedIntrospection::RubyCode.build_from_source(code).source_from_ast
  end

  describe "#create" do

    subject { ->(partials) {
      s = described_class.new(file:                 file_in,
                              file_out:             file_out,
                              schema_scrapper:      stub_schema_scrapper,
                              enabled_partials:     partials,
                              klasses_to_be_mocked: [],
                              mock_append_name:     "Mock").create
      expect(s.errors).to eq []
      format_code(File.open(file_out.path).read)
    } }

    let(:file_out) {
      Tempfile.new('fileOut')
    }

    let(:file_in) {
      File.new(File.join(File.dirname(__FILE__), "../models/model.rb"))
    }

    let(:rails_model) {
      double("RailsModel")
    }

    let(:stub_schema_scrapper) {
      s = ActiveRecordSchemaScrapper.new(model: rails_model)
      allow(s).to receive(:attributes) { sample_attributes }
      allow(s).to receive(:associations) { sample_associations }
      allow(s).to receive(:table_name) { "example_table" }
      allow(s).to receive(:abstract_class?) { false }
      s
    }

    let(:sample_attributes) {
      a = ActiveRecordSchemaScrapper::Attributes.new(model: rails_model)
      allow(a).to receive(:to_a) { [ActiveRecordSchemaScrapper::Attribute.new(name: "example_attribute", type: :string)] }
      a
    }

    let(:sample_associations) {
      a = ActiveRecordSchemaScrapper::Associations.new(model: rails_model)
      allow(a).to receive(:to_a) { [
        ActiveRecordSchemaScrapper::Association.new(name: :user, class_name: :User, type: :belongs_to, through: nil, source: nil, foreign_key: :user_id, join_table: nil, dependent: nil),
        ActiveRecordSchemaScrapper::Association.new(name: :account, class_name: :Account, type: :has_one, through: nil, source: nil, foreign_key: :account_id, join_table: nil, dependent: nil),
        ActiveRecordSchemaScrapper::Association.new(name: :person, class_name: :Person, type: :has_many, through: nil, source: nil, foreign_key: :person_id, join_table: nil, dependent: nil),
        ActiveRecordSchemaScrapper::Association.new(name: :other, class_name: :Other, type: :has_and_belongs_to_many, through: nil, source: nil, foreign_key: :other_id, join_table: nil, dependent: nil),
      ] }
      a
    }

    describe "error cases" do
      let(:file_in) {
        f = Tempfile.new('name')
        f.write model_string
        f.close
        File.open(f.path)
      }
      subject {
        described_class.new(file:                 file_in,
                            file_out:             file_out,
                            schema_scrapper:      stub_schema_scrapper,
                            enabled_partials:     [],
                            klasses_to_be_mocked: [],
                            mock_append_name:     "Mock").create
      }
      describe 'has no parent class' do
        let(:model_string) {
          <<-RUBY.strip_heredoc
        class ParentLessChild
        end
          RUBY
        }

        it do
          expect(subject.errors.first.message).to eq("ParentLessChild is missing a parent class.")
          expect(subject.completed?).to eq false
          expect(file_out.read).to eq ""
        end
      end

      describe 'adding to valid parent classes' do
        subject {
          described_class.new(file:                 file_in,
                              file_out:             file_out,
                              schema_scrapper:      stub_schema_scrapper,
                              enabled_partials:     [],
                              klasses_to_be_mocked: [],
                              mock_append_name:     "Mock"
          ).create
        }
        let(:model_string) {
          <<-RUBY.strip_heredoc
        class Child < ActiveRecord::Base
        end
          RUBY
        }

        it do
          expect(subject.errors.empty?).to eq true
          expect(subject.completed?).to eq true
        end
      end
    end

    it "run all partials" do
      expect(subject.call(nil).class).to eq String
    end

    context "when it mock is in modules" do
      let(:file_in) {
        File.new(File.join(File.dirname(__FILE__), "../models/model.rb"))
      }

      it 'partial :attributes' do
        expect(subject.call([:attributes])).to eq format_code <<-RUBY.strip_heredoc
        require 'active_mocker/mock'

        class ModelMock < ActiveMocker::Base
          created_with('#{ActiveMocker::VERSION}')
          def example_attribute
            read_attribute(:example_attribute)
          end

          def example_attribute=(val)
            write_attribute(:example_attribute, val)
          end

          def id
            read_attribute(:id)
          end

          def id=(val)
            write_attribute(:id, val)
          end

        end
        RUBY
      end
    end

    it 'partial :attributes' do
      expect(subject.call([:attributes])).to eq format_code <<-RUBY.strip_heredoc
        require 'active_mocker/mock'

        class ModelMock < ActiveMocker::Base
          created_with('#{ActiveMocker::VERSION}')
          def example_attribute
            read_attribute(:example_attribute)
          end

          def example_attribute=(val)
            write_attribute(:example_attribute, val)
          end

          def id
            read_attribute(:id)
          end

          def id=(val)
            write_attribute(:id, val)
          end

        end
      RUBY
    end

    it 'partial :class_methods' do
      expect(subject.call([:class_methods])).to eq format_code <<-RUBY.strip_heredoc
        require 'active_mocker/mock'

        class ModelMock < ActiveMocker::Base
          created_with('#{ActiveMocker::VERSION}')
          class << self
            def attributes
              @attributes ||= HashWithIndifferentAccess.new({"example_attribute"=>nil, "id"=>nil}).merge(super)
            end

            def types
              @types ||= ActiveMocker::HashProcess.new({ example_attribute: String, id: Fixnum }, method(:build_type)).merge(super)
            end

            def associations
              @associations ||= {:user=>nil, :account=>nil, :person=>nil, :other=>nil}.merge(super)
            end

            def associations_by_class
              @associations_by_class ||= {"User"=>{:belongs_to=>[:user]}, "Account"=>{:has_one=>[:account]}, "Person"=>{:has_many=>[:person]}, "Other"=>{:has_and_belongs_to_many=>[:other]}}.merge(super)
            end

            def mocked_class
              "Model"
            end

            private :mocked_class

            def attribute_names
              @attribute_names ||= ["example_attribute", "id"] | super
            end

            def primary_key
              "id"
            end

            def abstract_class?
              false
            end

            def table_name
              "example_table" || super
            end

          end
        end
      RUBY
    end

    it 'partial :modules_constants' do
      expect(subject.call([:modules_constants])).to eq format_code <<-RUBY.strip_heredoc
        require 'active_mocker/mock'

        class ModelMock < ActiveMocker::Base
          created_with('#{ActiveMocker::VERSION}')
          MY_CONSTANT_VALUE = 3
          prepend PostMethods
        end
      RUBY
    end

    it 'partial :scopes' do
      results = subject.call([:scopes])
      expect(results).to eq format_code <<-RUBY.strip_heredoc
        require 'active_mocker/mock'

        class ModelMock < ActiveMocker::Base
          created_with('#{ActiveMocker::VERSION}')
          module Scopes
            include ActiveMocker::Base::Scopes

            def named(name, value=nil, options=nil)
              ActiveMocker::LoadedMocks.find('Model').send(:call_mock_method, method: 'named', caller: Kernel.caller, arguments: [name, value, options])
            end

            def other_named
              ActiveMocker::LoadedMocks.find('Model').send(:call_mock_method, method: 'other_named', caller: Kernel.caller, arguments: [])
            end

          end

          extend Scopes

          class ScopeRelation < ActiveMocker::Association
            include ModelMock::Scopes
          end

          def self.__new_relation__(collection)
            ModelMock::ScopeRelation.new(collection)
          end

          private_class_method :__new_relation__
        end
      RUBY
    end

    it 'partial :defined_methods' do
      expect(subject.call([:defined_methods])).to eq format_code <<-RUBY.strip_heredoc
        require 'active_mocker/mock'

        class ModelMock < ActiveMocker::Base
          created_with('#{ActiveMocker::VERSION}')
          def foo(foobar, value)
            call_mock_method(method: __method__, caller: Kernel.caller, arguments: [foobar, value])
          end
          def superman
            call_mock_method(method: __method__, caller: Kernel.caller, arguments: [])
          end
          def self.bang!
            call_mock_method(method: __method__, caller: Kernel.caller, arguments: [])
          end
          def self.duper(value, *args)
            call_mock_method(method: __method__, caller: Kernel.caller, arguments: [value, args])
          end
          def self.foo
            call_mock_method(method: __method__, caller: Kernel.caller, arguments: [])
          end

        end
      RUBY
    end

    it 'partial :associations' do
      expect(subject.call([:associations])).to eq format_code <<-RUBY.strip_heredoc
        require 'active_mocker/mock'

        class ModelMock < ActiveMocker::Base
          created_with('#{ActiveMocker::VERSION}')
          def user
            read_association(:user) || write_association(:user, classes("User").try do |k|
              k.find_by(id: user_id)
            end)
          end

          def user=(val)
            write_association(:user, val)
            ActiveMocker::BelongsTo.new(val, child_self: self, foreign_key: :user_id).item
          end

          def build_user(attributes={}, &block)
            association = classes('User').try(:new, attributes, &block)
            write_association(:user, association) unless association.nil?
          end

          def create_user(attributes={}, &block)
            association = classes('User').try(:create,attributes, &block)
            write_association(:user, association) unless association.nil?
          end

          alias_method :create_user!, :create_user
          def account
            read_association(:account)
          end

          def account=(val)
            write_association(:account, val)
            ActiveMocker::HasOne.new(val, child_self: self, foreign_key: 'account_id').item
          end

          def build_account(attributes={}, &block)
            write_association(:account, classes('Account').new(attributes, &block)) if classes('Account')
          end

          def create_account(attributes={}, &block)
            write_association(:account, classes('Account').new(attributes, &block)) if classes('Account')
          end
          alias_method :create_account!, :create_account

          def person
            read_association(:person, -> { ActiveMocker::HasMany.new([],foreign_key: 'person_id', foreign_id: self.id, relation_class: classes('Person'), source: '') })
          end

          def person=(val)
            write_association(:person, ActiveMocker::HasMany.new(val, foreign_key: 'person_id', foreign_id: self.id, relation_class: classes('Person'), source: ''))
          end

          def other
            read_association(:other, ->{ ActiveMocker::HasAndBelongsToMany.new([]) })
          end

          def other=(val)
            write_association(:other, ActiveMocker::HasAndBelongsToMany.new(val))
          end
        end
      RUBY
    end
  end
end
