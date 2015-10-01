`import poplistComponent from '../components/eui-poplist'`
`import disabledSupport from '../mixins/disabled-support'`
`import errorSupport from '../mixins/error-support'`
`import widthSupport from '../mixins/width-support'`

select = Em.Component.extend disabledSupport, errorSupport, widthSupport,
  tagName: 'eui-select'
  classNameBindings: ['isDisabled:eui-disabled', 'class']

  baseClass: 'select'
  style: 'default'
  size: 'medium'

  showPoplist: false
  required: false
  options: []
  labelPath: 'label'
  valuePath: 'value'

  _selection: null

  selectClass: Ember.computed 'size', 'style', ->
    baseClass = @get 'baseClass'
    size = @get 'size'
    style = @get 'style'

    return "eui-#{baseClass}-button-#{size}-#{style}"


  # WAI-ARIA support values

  ariaHasPopup: true

  ariaOwns: Ember.computed 'poplist', ->
    @get('poplist.elementId')


  # Holds a reference to the poplist component when it is open

  poplist: null


  # Width of the poplist

  listWidth: 'auto'


  # Stores a object that we will consider to be null. If this object is selected we
  # will return null instead

  nullValue: new Object()


  # If this field is not required we automatically add a copy of the nullValue object at
  # the top of the list. This acts as a zero value so the user can deselect all options.

  optionsWithBlank: Ember.computed 'options.@each', 'required', ->
    options = @get 'options'
    paddedOptions = options[..]

    unless @get 'required'
      paddedOptions.unshift @get 'nullValue'

    return paddedOptions


  # Label of the selected option or the placeholder text

  label: Ember.computed 'selection', 'placeholder', 'labelPath', ->
    labelPath = @get 'labelPath'
    return @get("selection.#{labelPath}") || @get 'placeholder'


  # Current option the user has selected. It is a wrapper around _selection
  # which the poplist binds to. It allows us to return null when the user selects
  # the nullValue object we inserted.

  selection: Ember.computed '_selection',
    get: (key) ->
      selection = @get '_selection'
      nullValue = @get 'nullValue'
      if selection == nullValue then null else selection

    set: (key, value) ->
      @set '_selection', value
      value


  # Computes the value of the selection based on the valuePath specified by the user.
  # Allows for getting and setting so the user can set the initial value of the select
  # without passing in the full object

  value: Ember.computed 'selection', 'valuePath',
    get: (key) ->
      valuePath = @get 'valuePath'
      if valuePath then @get("selection.#{valuePath}") else null

    set: (key, value) ->
      valuePath = @get 'valuePath'

      if valuePath
        selection = @get('options').find (option) ->
          return option.get(valuePath) is value

      @set 'selection', selection || value
      value


  initialization: Ember.on 'init', ->
    # Make sure we have options or things will break badly
    if @get('options') is undefined
      Ember.Logger.error ('EmberUI: eui-select options paramater has undefined value')
      return

    # Create observer for the selection's label so we can monitor it for changes
    labelPath = 'selection.' + @get 'labelPath'
    @addObserver(labelPath, -> @notifyPropertyChange 'label')

    # Set the initial selection based on the value
    valuePath = @get 'valuePath'
    value = @get 'value'

    if valuePath
      value = @get('options').find (option) ->
        return option[valuePath] is value

    @set('_selection', value || @get 'nullValue')


  click: ->
    @toggleProperty('showPoplist')


  # Down Arrow Key

  keyUp: (event) ->
    if event.which == 40
      event.preventDefault()
      @click()


  # Error check should happen without user having to focus on component

  isEntered: true

`export default select`
