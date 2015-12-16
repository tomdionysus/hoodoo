require 'spec_helper'
require 'active_record'

describe Hoodoo::ActiveRecord::Dated do

  before :all do
    spec_helper_silence_stdout() do

      ActiveRecord::Migration.create_table( :r_spec_model_effective_date_tests, :id => false ) do | t |
        t.text :id,  :null => false
        t.text :data
        t.timestamps
      end

      ActiveRecord::Migration.create_table( :r_spec_model_effective_date_tests_history_entries, :id => false ) do | t |
        t.text     :id,              :null => false
        t.text     :uuid,            :null => false
        t.text     :data
        t.datetime :effective_start, :null => false
        t.datetime :effective_end,   :null => false
        t.timestamps
      end

      class RSpecModelEffectiveDateTest < ActiveRecord::Base
        include Hoodoo::ActiveRecord::Dated
        dating_enabled()
      end

      ActiveRecord::Migration.create_table( :r_spec_model_effective_date_test_overrides, :id => false ) do | t |
        t.text :id,  :null => false
        t.text :data
        t.timestamps
      end

      ActiveRecord::Migration.create_table( :r_spec_model_effective_date_history_entries, :id => false ) do | t |
        t.text     :id,              :null => false
        t.text     :uuid,            :null => false
        t.text     :data
        t.datetime :effective_start, :null => false
        t.datetime :effective_end,   :null => false
        t.timestamps
      end

      class RSpecModelEffectiveDateTestOverride < ActiveRecord::Base
        include Hoodoo::ActiveRecord::Dated

        dating_enabled( :history_table_name => :r_spec_model_effective_date_history_entries )
      end
    end
  end

  shared_examples Hoodoo::ActiveRecord::Dated do

    before( :all ) do

      # Create some examples data for finding. The data has two different UUIDs
      # which I'll referer to as A and B. The following tables contain the
      # historical and current records separately with their attributes.
      #
      # Historical:
      # -------------------------------------------------------------------
      #  uuid | data    | created_at    | effective_end | effective_start |
      # -------------------------------------------------------------------
      #  A    | "one"   | now - 5 hours | now - 3 hours | now - 5 hours   |
      #  B    | "two"   | now - 4 hours | now - 2 hours | now - 4 hours   |
      #  A    | "three" | now - 5 hours | now - 1 hour  | now - 3 hours   |
      #  B    | "four"  | now - 4 hours | now           | now - 2 hour    |
      #
      # Current:
      # --------------------------------
      #  uuid | data   | created_at    |
      # --------------------------------
      #  B    | "five" | now - 4 hours |
      #  A    | "six"  | now - 5 hours |
      #

      @uuid_a = Hoodoo::UUID.generate
      @uuid_b = Hoodoo::UUID.generate

      @now  = Time.now.utc

      # uuid, data, created_at, effective_end, effective_start
      [
        [ @uuid_a, "one",   @now - 5.hours, @now - 3.hours, @now - 5.hours ],
        [ @uuid_b, "two",   @now - 4.hours, @now - 2.hours, @now - 4.hours ],
        [ @uuid_a, "three", @now - 5.hours, @now - 1.hour,  @now - 3.hours ],
        [ @uuid_b, "four",  @now - 4.hours, @now,           @now - 2.hours ]
      ].each do | row_data |
        model_klass.dated_with.new( {
          :id              => row_data[ 0 ] + "-" + row_data[ 3 ].iso8601,
          :uuid            => row_data[ 0 ],
          :data            => row_data[ 1 ],
          :created_at      => row_data[ 2 ],
          :effective_end   => row_data[ 3 ],
          :effective_start => row_data[ 4 ]
        } ).save!
      end

      # uuid, data, created_at, updated_at
      [
        [ @uuid_b, "five", @now - 4.hours, @now          ],
        [ @uuid_a, "six",  @now - 5.hours, @now - 1.hour ]
      ].each do | row_data |
        model_klass.new( {
          :id         => row_data[ 0 ],
          :data       => row_data[ 1 ],
          :created_at => row_data[ 2 ],
          :updated_at => row_data[ 3 ]
        } ).save!
      end

    end

    context '.dated_at' do
      it 'returns counts correctly' do
        expect( model_klass.dated_at( @now - 10.hours ).count ).to be 0
        expect( model_klass.dated_at( @now ).count ).to be 2
      end

      def test_expectation( time, expected_data )
        expect( model_klass.dated_at( time ).pluck( :data ) ).to match_array( expected_data )
      end

      it 'returns no records before any were effective' do
        test_expectation( @now - 10.hours, [] )
      end

      it 'returns records that used to be effective starting at past time' do
        test_expectation( @now - 5.hours, [ "one"           ] )
        test_expectation( @now - 4.hours, [ "one", "two"    ] )
        test_expectation( @now - 3.hours, [ "two", "three"  ] )
        test_expectation( @now - 2.hours, [ "three", "four" ] )
        test_expectation( @now - 1.hour,  [ "four", "six"   ] )
      end

      it 'returns records that are effective now' do
        test_expectation( @now, [ "five", "six" ] )
      end

      it 'works with further filtering' do
        expect( model_klass.dated_at( @now ).where( :id => @uuid_a ).pluck( :data ) ).to eq( [ "six" ] )
      end

    end

    context '.dated' do
      it 'returns counts correctly' do
        # The contents of the Context are irrelevant aside from the fact that it
        # needs a request to store the dated_at value.
        request = Hoodoo::Services::Request.new
        context = Hoodoo::Services::Context.new( nil, request, nil, nil )

        context.request.dated_at = @now - 10.hours
        expect( model_klass.dated( context ).count ).to be 0

        context.request.dated_at = @now
        expect( model_klass.dated( context ).count ).to be 2
      end

      def test_expectation( time, expected_data )
        # The contents of the Context are irrelevant aside from the fact that it
        # needs a request to store the dated_at value.
        request = Hoodoo::Services::Request.new
        context = Hoodoo::Services::Context.new( nil, request, nil, nil )
        context.request.dated_at = time

        expect( model_klass.dated( context ).pluck( :data ) ).to match_array( expected_data )
      end

      it 'returns no records before any were effective' do
        test_expectation( @now - 10.hours, [] )
      end

      it 'returns records that used to be effective starting at past time' do
        test_expectation( @now - 5.hours, [ "one"           ] )
        test_expectation( @now - 4.hours, [ "one", "two"    ] )
        test_expectation( @now - 3.hours, [ "two", "three"  ] )
        test_expectation( @now - 2.hours, [ "three", "four" ] )
        test_expectation( @now - 1.hour,  [ "four", "six"   ] )
      end

      it 'returns records that are effective now' do
        test_expectation( @now, [ "five", "six" ] )
      end

      it 'works with further filtering' do

        # The contents of the Context are irrelevant aside from the fact that it
        # needs a request to store the dated_at value.
        request = Hoodoo::Services::Request.new
        context = Hoodoo::Services::Context.new( nil, request, nil, nil )
        context.request.dated_at = @now

        expect( model_klass.dated( context ).where( :id => @uuid_a ).pluck( :data ) ).to eq( [ "six" ] )
      end

      it 'works with dating last' do

        # The contents of the Context are irrelevant aside from the fact that it
        # needs a request to store the dated_at value.
        request = Hoodoo::Services::Request.new
        context = Hoodoo::Services::Context.new( nil, request, nil, nil )
        context.request.dated_at = @now

        expect( model_klass.where( :id => @uuid_a ).dated( context ).pluck( :data ) ).to eq( [ "six" ] )
      end

    end

    context '.dated_historical_and_current' do

      it 'returns counts correctly' do
        expect( model_klass.dated_historical_and_current.count ).to be 6
      end

      it 'lists all historical and current records' do
        expect( model_klass.dated_historical_and_current.pluck( :data ) ).to match_array( [ 'one', 'two', 'three', 'four', 'five', 'six' ] )
      end

    end

  end

  context "using default effective dating config" do

    # Must be defined as a method rather than using a let statement as let
    # statement values cannot be used in before blocks.
    def model_klass
      RSpecModelEffectiveDateTest
    end

    it_behaves_like Hoodoo::ActiveRecord::Dated

  end

  context "overriding history table name" do

    # Must be defined as a method rather than using a let statement as let
    # statement values cannot be used in before blocks.
    def model_klass
      RSpecModelEffectiveDateTestOverride
    end

    it_behaves_like Hoodoo::ActiveRecord::Dated

  end

end