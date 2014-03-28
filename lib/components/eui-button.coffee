`import styleSupport from '../mixins/style-support'`
`import sizeSupport from '../mixins/size-support'`
`import disabledSupport from '../mixins/disabled-support'`

button = Em.Component.extend styleSupport, sizeSupport, disabledSupport,
  classNameBindings: [':eui-button', 'loading:eui-loading', 'icon:eui-icon', 'label::eui-no-label', 'class']

  label: null
  icon: null
  trailingIcon: null
  loading: null
  disabled: null
  action: null
  class: null

  click: (event) ->
    event.preventDefault()
    @sendAction('action', @get('context'))

`export default button`
