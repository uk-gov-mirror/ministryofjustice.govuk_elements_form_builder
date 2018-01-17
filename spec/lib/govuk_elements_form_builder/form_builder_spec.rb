# coding: utf-8
require 'rails_helper'
require 'spec_helper'

class TestHelper < ActionView::Base; end

RSpec.describe GovukElementsFormBuilder::FormBuilder do
  include TranslationHelper

  it "should have a version" do
    expect(GovukElementsFormBuilder::VERSION).to eq("0.1.1")
  end

  let(:helper) { TestHelper.new }
  let(:resource)  { Person.new }
  let(:builder) { described_class.new :person, resource, helper, {} }

  def expect_equal output, expected
    split_output = output.gsub(">\n</textarea>", ' />').split("<").join("\n<").split(">").join(">\n").squeeze("\n").strip + '>'
    split_expected = expected.join("\n")
    expect(split_output).to eq split_expected
  end

  def element_for(method)
    method == :text_area ? 'textarea' : 'input'
  end

  def type_for(method, type)
    method == :text_area ? '' : %'type="#{type}" '
  end

  def html_attributes(hash)
    if  hash.present?
      hash.map{|k,v| %'#{k}="#{v}" '}.join(' ')
    end
  end

  shared_examples_for 'input field' do |method, type|

    def size(method, size)
      (size.nil? || method == :text_area) ? '' : %'size="#{size}" '
    end

    def expected_name_input_html method, type, classes=nil, size=nil, label_options=nil
      label_options ||= {}
      label_options[:class] ||= nil
      [
        '<div class="form-group">',
        %'<label #{html_attributes(label_options.except(:class, :for))}class="form-label#{label_options[:class]}" for="person_name">',
        'Full name',
        '</label>',
        %'<#{element_for(method)} #{size(method, size)}class="form-control#{classes}" #{type_for(method, type)}name="person[name]" id="person_name" />',
        '</div>'
      ]
    end

    it 'outputs label and input wrapped in div' do
      output = builder.send method, :name

      expect_equal output, expected_name_input_html(method, type)
    end

    it 'adds custom class to input when passed class: "custom-class"' do
      output = builder.send method, :name, class: 'custom-class'

      expect_equal output, expected_name_input_html(method, type, ' custom-class')
    end

    it 'adds custom classes to input when passed class: ["custom-class", "another-class"]' do
      output = builder.send method, :name, class: ['custom-class', 'another-class']

      expect_equal output, expected_name_input_html(method, type, ' custom-class another-class')
    end

    it 'adds custom classes to label when passed class: ["custom-class", "another-class"]' do
      label_class_options = { class: ' custom-label-class another-label-class' }
      output = builder.send method, :name, {label_options: {class: ['custom-label-class', 'another-label-class']}}

      expect_equal output, expected_name_input_html( method, type, nil, nil, label_class_options)
    end

    it 'passes other html attribute to the label if they are provided' do
      label_attr_options = { style: 'color:red;'}
      output = builder.send method, :name, {label_options: {style: 'color:red;'}}

      expect_equal output, expected_name_input_html( method, type, nil, nil, label_attr_options)
    end

    it 'passes options passed to text_field onto super text_field implementation' do
      output = builder.send method, :name, size: 100

      expect_equal output, expected_name_input_html(method, type, nil, 100)
    end

    context 'when hint text provided' do
      it 'outputs hint text in span inside label' do
        output = builder.send method, :ni_number
        expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_ni_number">',
          'National Insurance number',
          '<span class="form-hint">',
          'It’ll be on your last payslip. For example, JH 21 90 0A.',
          '</span>',
          '</label>',
          %'<#{element_for(method)} class="form-control" #{type_for(method, type)}name="person[ni_number]" id="person_ni_number" />',
          '</div>'
        ]
      end
    end

    context 'when fields_for used' do
      it 'outputs label and input with correct ids' do
        output = builder.fields_for(:address, Address.new) do |f|
          f.send method, :postcode
        end
        expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_address_attributes_postcode">',
          'Postcode',
          '</label>',
          %'<#{element_for(method)} class="form-control" #{type_for(method, type)}name="person[address_attributes][postcode]" id="person_address_attributes_postcode" />',
          '</div>'
        ]
      end
    end

    context 'when resource is a not a persisted model' do
      let(:resource) { Report.new }
      let(:builder) { described_class.new :report, resource, helper, {} }
      it "##{method} does not fail" do
        expect { builder.send method, :name }.not_to raise_error
      end
    end

    context 'when validation error on object' do
      it 'outputs error message in span inside label' do
        resource.valid?
        output = builder.send method, :name
        expected = expected_error_html method, type, 'person_name',
          'person[name]', 'Full name', 'Full name is required'
        expect_equal output, expected
      end

      it 'outputs custom error message format in span inside label' do
        translations = YAML.load(%'
            errors:
              format: "%{message}"
            activemodel:
              errors:
                models:
                  person:
                    attributes:
                      name:
                        blank: "Enter your full name"
        ')
        with_translations(:en, translations) do
          resource.valid?
          output = builder.send method, :name
          expected = expected_error_html method, type, 'person_name',
            'person[name]', 'Name', 'Enter your full name'
          expect_equal output, expected
        end
      end
    end

    context 'when validation error on child object' do
      it 'outputs error message in span inside label' do
        resource.address = Address.new
        resource.address.valid?

        output = builder.fields_for(:address) do |f|
          f.send method, :postcode
        end

        expected = expected_error_html method, type, 'person_address_attributes_postcode',
          'person[address_attributes][postcode]', 'Postcode', 'Postcode is required'
        expect_equal output, expected
      end
    end

    context 'when validation error on twice nested child object' do
      it 'outputs error message in span inside label' do
        resource.address = Address.new
        resource.address.country = Country.new
        resource.address.country.valid?

        output = builder.fields_for(:address) do |address|
          address.fields_for(:country) do |country|
            country.send method, :name
          end
        end

        expected = expected_error_html method, type, 'person_address_attributes_country_attributes_name',
          'person[address_attributes][country_attributes][name]', 'Country', 'Country is required'
        expect_equal output, expected
      end
    end

  end

  context 'when mixing the rendering order of nested builders' do
    let(:method) { :text_field }
    let(:type) { :text }
    it 'outputs error messages in span inside label' do
      resource.address = Address.new
      resource.address.valid?
      resource.valid?

      # Render the postcode first
      builder.fields_for(:address) do |address|
        address.text_field :postcode
      end
      output = builder.text_field :name

      expected = expected_error_html :text_field, :text, 'person_name',
        'person[name]', 'Full name', 'Full name is required'
      expect_equal output, expected
    end
  end

  def expected_error_html method, type, attribute, name_value, label, error
    [
      %'<div class="form-group error" id="error_#{attribute}">',
      %'<label class="form-label" for="#{attribute}">',
      label,
      %'<span class="error-message" id="error_message_#{attribute}">',
      error,
      '</span>',
      '</label>',
      %'<#{element_for(method)} aria-describedby="error_message_#{attribute}" class="form-control" #{type_for(method, type)}name="#{name_value}" id="#{attribute}" />',
      '</div>'
    ]
  end

  describe '#text_field' do
    include_examples 'input field', :text_field, :text
  end

  describe '#text_area' do
    include_examples 'input field', :text_area, nil
  end

  describe '#email_field' do
    include_examples 'input field', :email_field, :email
  end

  describe "#number_field" do
    include_examples 'input field', :number_field, :number
  end

  describe '#password_field' do
    include_examples 'input field', :password_field, :password
  end

  describe '#phone_field' do
    include_examples 'input field', :phone_field, :tel
  end

  describe '#range_field' do
    include_examples 'input field', :range_field, :range
  end

  describe '#search_field' do
    include_examples 'input field', :search_field, :search
  end

  describe '#telephone_field' do
    include_examples 'input field', :telephone_field, :tel
  end

  describe '#url_field' do
    include_examples 'input field', :url_field, :url
  end

  describe '#radio_button_fieldset' do
    let(:pretty_output) { HtmlBeautifier.beautify output }

    it 'outputs radio buttons wrapped in labels' do
      output = builder.radio_button_fieldset :location, choices: [:ni, :isle_of_man_channel_islands, :british_abroad]
      expect_equal output, [
        '<div class="form-group">',
        '<fieldset>',
        '<legend>',
        '<span class="form-label-bold">',
        'Where do you live?',
        '</span>',
        '<span class="form-hint">',
        'Select from these options because you answered you do not reside in England, Wales, or Scotland',
        '</span>',
        '</legend>',
        '<label class="block-label selection-button-radio" for="person_location_ni">',
        '<input type="radio" value="ni" name="person[location]" id="person_location_ni" />',
        'Northern Ireland',
        '</label>',
        '<label class="block-label selection-button-radio" for="person_location_isle_of_man_channel_islands">',
        '<input type="radio" value="isle_of_man_channel_islands" name="person[location]" id="person_location_isle_of_man_channel_islands" />',
        'Isle of Man or Channel Islands',
        '</label>',
        '<label class="block-label selection-button-radio" for="person_location_british_abroad">',
        '<input type="radio" value="british_abroad" name="person[location]" id="person_location_british_abroad" />',
        'I am a British citizen living abroad',
        '</label>',
        '</fieldset>',
        '</div>'
      ]
    end

    it 'outputs yes/no choices when no choices specified, and adds "inline" class to fieldset when passed "inline: true"' do
      output = builder.radio_button_fieldset :has_user_account, inline: true
      expect_equal output, [
        '<div class="form-group">',
        '<fieldset class="inline">',
        '<legend>',
        '<span class="form-label-bold">',
        'Do you already have a personal user account?',
        '</span>',
        '</legend>',
        '<label class="block-label selection-button-radio" for="person_has_user_account_yes">',
        '<input type="radio" value="yes" name="person[has_user_account]" id="person_has_user_account_yes" />',
        'Yes',
        '</label>',
        '<label class="block-label selection-button-radio" for="person_has_user_account_no">',
        '<input type="radio" value="no" name="person[has_user_account]" id="person_has_user_account_no" />',
        'No',
        '</label>',
        '</fieldset>',
        '</div>'
      ]
    end

    it 'propagates html attributes down to the legend inner span if any provided, appending to the defaults' do
      output = builder.radio_button_fieldset :has_user_account, inline: true, legend_options: {class: 'visuallyhidden', lang: 'en'}
      expect(output).to match(/<legend><span class="form-label-bold visuallyhidden" lang="en">/)
    end

    context 'with a couple associated cases' do
      let(:case_1) { Case.new(id: 1, name: 'Case One')  }
      let(:case_2) { Case.new(id: 2, name: 'Case Two')  }
      let(:cases) { [case_1, case_2] }

      it 'accepts value_method and text_method to better control generated HTML' do
        output = builder.radio_button_fieldset :case_id, choices: cases, value_method: :id, text_method: :name, inline: true
        expect_equal output, [
                       '<div class="form-group">',
                       '<fieldset class="inline">',
                       '<legend>',
                       '<span class="form-label-bold">',
                       'Case',
                       '</span>',
                       '</legend>',
                       '<label class="block-label selection-button-radio" for="person_case_id_1">',
                       '<input type="radio" value="1" name="person[case_id]" id="person_case_id_1" />',
                       'Case One',
                       '</label>',
                       '<label class="block-label selection-button-radio" for="person_case_id_2">',
                       '<input type="radio" value="2" name="person[case_id]" id="person_case_id_2" />',
                       'Case Two',
                       '</label>',
                       '</fieldset>',
                       '</div>'
                     ]

      end
    end

    context 'the resource is invalid' do
      let(:resource) { Person.new.tap { |p| p.valid? } }

      it 'outputs error messages' do
        output = builder.radio_button_fieldset :gender
        expect_equal output, [
                       '<div class="form-group error" id="error_person_gender">',
                       '<fieldset>',
                       '<legend>',
                       '<span class="form-label-bold">',
                       'Gender',
                       '</span>',
                       '<span class="error-message">',
                       'Gender is required',
                       '</span>',
                       '</legend>',
                       '<label class="block-label selection-button-radio" for="person_gender_yes">',
                       '<input aria-describedby="error_message_person_gender_yes" type="radio" value="yes" name="person[gender]" id="person_gender_yes" />',
                       'Yes',
                       '</label>',
                       '<label class="block-label selection-button-radio" for="person_gender_no">',
                       '<input aria-describedby="error_message_person_gender_no" type="radio" value="no" name="person[gender]" id="person_gender_no" />',
                       'No',
                       '</label>',
                       '</fieldset>',
                       '</div>'
                     ]
      end
    end
  end

  describe '#check_box_fieldset' do
    before do
      resource.waste_transport = WasteTransport.new
    end

    it 'outputs checkboxes wrapped in labels' do
      output = builder.fields_for(:waste_transport) do |f|
        f.check_box_fieldset :waste_transport, [:animal_carcasses, :mines_quarries, :farm_agricultural]
      end

      expect_equal output, [
        '<div class="form-group">',
        '<fieldset>',
        '<legend>',
        '<span class="form-label-bold">',
        'Which types of waste do you transport regularly?',
        '</span>',
        '<span class="form-hint">',
        'Select all that apply',
        '</span>',
        '</legend>',
        '<label class="block-label selection-button-checkbox" for="person_waste_transport_attributes_animal_carcasses">',
        '<input name="person[waste_transport_attributes][animal_carcasses]" type="hidden" value="0" />',
        '<input type="checkbox" value="1" name="person[waste_transport_attributes][animal_carcasses]" id="person_waste_transport_attributes_animal_carcasses" />',
        'Waste from animal carcasses',
        '<br>',
        '<em>',
        'includes sloths and other Bradypodidae',
        '</em>',
        '</label>',
        '<label class="block-label selection-button-checkbox" for="person_waste_transport_attributes_mines_quarries">',
        '<input name="person[waste_transport_attributes][mines_quarries]" type="hidden" value="0" />',
        '<input type="checkbox" value="1" name="person[waste_transport_attributes][mines_quarries]" id="person_waste_transport_attributes_mines_quarries" />',
        'Waste from mines or quarries (&gt; 200 lbs)',
        '</label>',
        '<label class="block-label selection-button-checkbox" for="person_waste_transport_attributes_farm_agricultural">',
        '<input name="person[waste_transport_attributes][farm_agricultural]" type="hidden" value="0" />',
        '<input type="checkbox" value="1" name="person[waste_transport_attributes][farm_agricultural]" id="person_waste_transport_attributes_farm_agricultural" />',
        'Farm or agricultural waste',
        '</label>',
        '</fieldset>',
        '</div>'
      ]
    end

    it 'propagates html attributes down to the legend inner span if any provided, appending to the defaults' do
      output = builder.fields_for(:waste_transport) do |f|
        f.check_box_fieldset :waste_transport, [:animal_carcasses, :mines_quarries, :farm_agricultural], legend_options: {class: 'visuallyhidden', lang: 'en'}
      end
      expect(output).to match(/<legend><span class="form-label-bold visuallyhidden" lang="en">/)
    end
  end

  describe '#collection_select' do

    it 'outputs label and input wrapped in div ' do
      @gender = [:male, :female]
      output = builder.collection_select :gender, @gender , :to_s, :to_s
      expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_gender">',
          'Gender',

          '</label>',
          %'<select class="form-control" name="person[gender]" id="person_gender">',
          %'<option value="male">',
          'male',
          %'</option>',
          %'<option value="female">',
          'female',
          %'</option>',
          %'</select>',
          '</div>'
      ]
    end

    it 'outputs select lists with labels and hints' do
      @location = [:ni, :isle_of_man_channel_islands]
      output = builder.collection_select :location, @location , :to_s, :to_s, {}
      expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_location">',
          '{:ni=&gt;&quot;Northern Ireland&quot;, :isle_of_man_channel_islands=&gt;&quot;Isle of Man or Channel Islands&quot;, :british_abroad=&gt;&quot;I am a British citizen living abroad&quot;}',
          %'<span class="form-hint">',
          'Select from these options because you answered you do not reside in England, Wales, or Scotland',
          %'</span>',
          '</label>',
          %'<select class="form-control" name="person[location]" id="person_location">',
          %'<option value="ni">',
          'ni',
          %'</option>',%'<option value="isle_of_man_channel_islands">',
          'isle_of_man_channel_islands',
          %'</option>',
          %'</select>',
          '</div>'
      ]
    end

    it 'adds custom class to input when passed class: "custom-class"' do
      @gender = [:male, :female]
      output = builder.collection_select :gender, @gender , :to_s, :to_s, {}, class: "my-custom-style"
      expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_gender">',
          'Gender',
          '</label>',
          %'<select class="form-control my-custom-style" name="person[gender]" id="person_gender">',
          %'<option value="male">',
          'male',
          %'</option>',
          %'<option value="female">',
          'female',
          %'</option>',
          %'</select>',
          '</div>'
      ]
    end
    it 'includes blanks' do
      @gender = [:male, :female]
      output = builder.collection_select :gender, @gender , :to_s, :to_s, {include_blank: "Please select an option"}, {class: "my-custom-style"}
      expect_equal output, [
          '<div class="form-group">',
          '<label class="form-label" for="person_gender">',
          'Gender',
          '</label>',
          %'<select class="form-control my-custom-style" name="person[gender]" id="person_gender">',
          %'<option value="">',
          'Please select an option',
          %'</option>',
          %'<option value="male">',
          'male',
          %'</option>',
          %'<option value="female">',
          'female',
          %'</option>',
          %'</select>',
          '</div>'
      ]
    end
  end
end
