`import styleSupport from '../mixins/style-support'`
`import poplistLayout from '../templates/eui-poplist'`
`import itemViewClassTemplate from '../templates/eui-poplist-option'`

poplist = Em.Component.extend styleSupport,
  layout: poplistLayout
  classNames: ['eui-poplist']
  classNameBindings: ['isOpen::eui-closing']
  attributeBindings: ['tabindex']

  labelPath: 'label'
  options: null
  listHeight: '80'
  listRowHeight: '20'
  searchString: null

  # Index of option currently highlighted
  highlightedIndex: -1

  # If the poplist is opened using the keyboard then we use this value to restore the
  # focus where it was after the poplist closes.
  previousFocus: null

  # Option that is currently highlighted
  highlighted: Ember.computed (key, value) ->
    options = @get 'filteredOptions'

    # setter
    if arguments.length is 2
      index = options.indexOf value
      @set 'highlightedIndex', index
      value

    # getter
    else
      index = @get 'highlightedIndex'
      options.objectAt index

  .property 'highlightedIndex', 'filteredOptions'

  hide: ->
    @setProperties { isOpen: false, highlightedIndex: -1 }
    $(window).unbind('scroll.emberui')
    $(window).unbind('click.emberui')
    @get('previousFocus').focus()

    # Figure out if there is a closing animation so we can wait for it to finish
    # before we remove the view from the DOM. The only gotcha is if you have a
    # open animation then you must have a closing animation
    animation = false
    domPrefixes = ['Webkit', 'Moz', 'O', 'ms']

    # check no-prefix support
    animation = true if this.$().css 'animationName'

    for prefix in domPrefixes
      animation = true if this.$().css prefix + 'animationName'

    if animation
      @$().one 'webkitAnimationEnd mozAnimationEnd oanimationend msAnimationEnd animationend', =>
        @destroy()
    else
      @destroy()

  didInsertElement: ->
    @set 'isOpen', true
    @set 'previousFocus', $("*:focus")

    # Focus on search input to ensure we can catch keyboard input. Do this after the
    # poplist is positioned to ensure it is visible. Failure to do so will result in
    # the page scrolling and closing the poplist
    Ember.run.next this, -> @focusOnSearch()

    # Ensure the selected option is visible and center it
    Ember.run.next this, -> @scrollToSelection @get('options').indexOf(@get 'selection'), true

  focusOnSearch: ->
    @$().find('input:first').focus()

  # Set the selection back to the first option if the users changes the search query
  # TODO: This doesn't fire the bindings on the listView correctly and you end up with multiple items highlighted.
  searchStringDidChange: (->
    @set 'highlightedIndex', 0 if @get 'searchString'
  ).observes 'searchString'

  # Filter the option list based on the query entered into the search box
  filteredOptions: (->
    options = @get 'options'
    query = @get 'searchString'

    return [] unless options
    return options unless query

    labelPath = @get 'labelPath'

    escapedQuery = query.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&")
    regex = new RegExp(escapedQuery, 'i')

    filteredOptions = options.filter (item, index, self) ->
      label = item.get?(labelPath) or item[labelPath]
      regex.test(label) if label

    return filteredOptions
  ).property 'options.@each', 'labelPath', 'searchString'

  hasNoOptions: Ember.computed.empty 'filteredOptions'

  # Updates the list-view's height based on the number of options
  optionsLengthDidChange: (->
    @updateListHeight()
  ).observes 'filteredOptions.length'

  updateListHeight: ->
    optionCount = @get 'filteredOptions.length'
    rowHeight = @get 'listRowHeight'

    if optionCount <= 12
      @set 'listHeight', optionCount * rowHeight
    else
      @set 'listHeight', 10 * rowHeight

  # Scroll the list to make sure the given option is visible.
  # Copied from https://github.com/Addepar/ember-widgets/
  scrollToSelection: (index, center) ->
    $listView  = @.$('.ember-list-view')
    listView   = Ember.View.views[$listView.attr('id')]
    startIndex = listView._startingIndex()
    numRows    = listView._childViewCount() - 1
    endIndex   = startIndex + numRows

    if index is 0
      $listView.scrollTop 0
    else if index < startIndex
      $listView.scrollTop index * @get 'listRowHeight'
    else if index >= endIndex
      if center
        $listView.scrollTop (index - (numRows / 2)) * @get 'listRowHeight'
      else
        $listView.scrollTop (index - numRows + 1) * @get 'listRowHeight'

  # Keyboard controls

  KEY_MAP:
    27: 'escapePressed'
    13: 'enterPressed'
    38: 'upArrowPressed'
    40: 'downArrowPressed'

  keyDown: (event) ->
    keyMap = @get 'KEY_MAP'
    method = keyMap[event.which]
    @get(method)?.apply(this, arguments) if method

  escapePressed: (event) ->
    @hide()

  enterPressed: (event) ->
    event.preventDefault()
    @set 'selection', @get 'highlighted'
    @hide()

  downArrowPressed: (event) ->
    event.preventDefault() # Don't let the page scroll down
    @adjustHighlight(1)

  upArrowPressed: (event) ->
    event.preventDefault() # Don't let the page scroll down
    @adjustHighlight(-1)


  adjustHighlight: (indexAdjustment) ->
    highlightedIndex = @get 'highlightedIndex'
    options = @get 'filteredOptions'
    optionsLength = options.get 'length'
    newIndex

    # If the current index is out of bounds they searched
    # so we adjust it back in
    if highlightedIndex >= optionsLength
      newIndex = 0 if indexAdjustment == 1

    else
      newIndex = highlightedIndex + indexAdjustment

      # Don't let highlighted option get out of bounds
      if newIndex >= optionsLength
        newIndex = optionsLength - 1

      else if newIndex < 0
        newIndex = 0

    # Make sure the current option is visible
    @scrollToSelection(newIndex)

    @set 'highlightedIndex', newIndex


  # List View

  listView: Ember.ListView.extend
    # Overriding this temporarily to fix the scrollbars in Firefox
    # Remove once https://github.com/emberjs/list-view/pull/113 is integrated
    css:
      position: 'relative'
      overflow: 'auto'
      '-webkit-overflow-scrolling': 'touch'
      'overflow-scrolling': 'touch'

    classNames: ['eui-options']
    height: Ember.computed.alias 'controller.listHeight'
    rowHeight: Ember.computed.alias 'controller.listRowHeight'

    didInsertElement: ->
      @_super()

      # Prevents mouse scroll events from passing through to the div
      # behind the poplist when listView is scrolled to the end. Fixes
      # the poplist closing if you scroll too far down
      @.$().bind('mousewheel DOMMouseScroll', (e) =>
        e.preventDefault()
        scrollTo = @get 'scrollTop'

        if e.type == 'mousewheel'
          scrollTo += (e.originalEvent.wheelDelta * -1)

        else if e.type == 'DOMMouseScroll'
          scrollTo += 40 * e.originalEvent.detail

        @scrollTo(scrollTo)
      )

    itemViewClass: Ember.ListItemView.extend
      classNames: ['eui-option']
      classNameBindings: ['isHighlighted:eui-hover', 'isSelected:eui-selected']
      template: itemViewClassTemplate

      # creates Label property based on specified labelPath
      labelPathDidChange: (->
        labelPath = @get 'controller.labelPath'
        Ember.defineProperty(this, 'label', Ember.computed.alias("content.#{labelPath}"))
        @notifyPropertyChange 'label'
      ).observes 'content', 'controller.labelPath'

      initializeLabelPath: (->
        @labelPathDidChange()
      ).on 'init'

      # Bindings won't fire if bound to context
      updateContext: (context) ->
        @_super context
        @set 'content', context

      isHighlighted: Ember.computed ->
        @get('controller.highlighted') is @get('content')
      .property 'controller.highlighted', 'content'

      isSelected: Ember.computed ->
        @get('controller.selection') is @get('content')
      .property 'controller.selection', 'content'

      click: ->
        @set 'controller.selection', @get 'content'
        @get('controller').hide()

      mouseEnter: ->
        options = @get 'controller.filteredOptions'
        hoveredOption = @get 'content'
        @set 'controller.highlighted', hoveredOption


poplist.reopenClass
  show: (options = {}) ->
    poplist = @.create options
    poplist.container = poplist.get 'targetObject.container'
    poplist.appendTo '.ember-application'

    poplist.updateListHeight()

    Ember.run.next this, -> @position(options.targetObject, poplist)
    poplist

  # TODO: Rewrite as reusable position function
  position: (targetObject, poplist) ->
    element = targetObject.$()
    poplistElement = poplist.$()

    offset = element.offset()

    # set a reasonable min-width on the poplist before we caclulate its actual size
    # TODO: Min-width is no longer sufficient because we use list-view which uses
    # absolute positioning. This means the popup can no longer get pushed wider
    # by its children. Need a new approach.
    elementWidthMinuspoplistPadding = element.width() - parseFloat(poplistElement.css('paddingLeft')) - parseFloat(poplistElement.css('paddingRight'))
    poplistElement.css('min-width', elementWidthMinuspoplistPadding)

    # calculate all the numbers needed to set positioning
    elementPositionTop = offset.top - element.scrollTop()
    elementPositionLeft = offset.left - element.scrollLeft()
    elementHeight = element.height()
    elementWidth = element.width()
    poplistWidth = poplistElement.width()
    poplistHorizontalPadding = parseFloat(poplistElement.css('paddingLeft')) + parseFloat(poplistElement.css('paddingRight'))
    windowScrollTop = $(window).scrollTop()
    windowScrollLeft = $(window).scrollLeft()

    poplistPositionTop = elementPositionTop + elementHeight  - windowScrollTop
    poplistPositionLeft = elementPositionLeft + elementWidth - poplistWidth - poplistHorizontalPadding - windowScrollLeft

    poplistElement.css('top', poplistPositionTop)
    poplistElement.css('left', poplistPositionLeft)

    $(window).bind 'scroll.emberui', ->
      poplist.hide()

    $(window).bind 'click.emberui', (event) ->
      unless $(event.target).parents('.eui-poplist').length
        event.preventDefault()
        poplist.hide()


`export default poplist`
