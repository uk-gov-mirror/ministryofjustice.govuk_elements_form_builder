module GovukElementsFormBuilder
  class FormBuilder < ActionView::Helpers::FormBuilder
    delegate :content_tag, :tag, to: :@template

    %w[text_field email_field].each do |method_name|
      define_method(method_name) do |name, *args |
        content_tag :div, class: 'form-group' do
          options = args.extract_options!
          text_field_class = ["form-control"]
          options[:class] = text_field_class

          label = label(name, class: "form-label")
          add_hint label, name
          (label + super(name, options.except(:label)) ).html_safe
        end
      end
    end

    private

    def add_hint label, name
      if hint = hint_text(name)
        hint_span = content_tag(:span, hint, class: 'form-hint')
        label.sub!('</label>', hint_span + '</label>'.html_safe)
      end
    end

    def hint_text name
      I18n.t("#{object_name}.#{name}", default: "", scope: 'helpers.hint').presence
    end

  end
end
