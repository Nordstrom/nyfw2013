
root = exports ? this

getCoords = (data) ->
  c = []
  data.forEach (d,i) ->
    # c.push([d.lon, d.lat])
    c.push({"type":"Feature", "id":i, "geometry":{"type":"Point", "coordinates":[d.lon,d.lat]},"properties":d})
  c

prettyName = (d) ->
  name = d.country
  if d.region and d.local
    if d.country == 'United States'
      name = "#{d.local}, #{d.region}"
    else
      name = "#{d.local}, #{d.country}"
  else if d.region
    name = d.region
  else if d.local
    name = d.local

  name

MoveBubbles = () ->
  # standard variables accessible to
  # the rest of the functions inside Bubbles
  width = 940
  height = 610
  data = []
  node = null
  label = null
  margin = {top: 5, right: 0, bottom: 0, left: 0}
  # largest size for our bubbles
  maxRadius = 65

  centers = {brand: {x:300, y:300}, other: {x:500, y:300}}
  split = false

  grav = -0.01

  charge = (d) ->
    -Math.pow(rScale(rValue(d)), 2.0) / 7

  # this scale will be used to size our bubbles
  rScale = d3.scale.sqrt().range([4,maxRadius])
  
  # I've abstracted the data value used to size each
  # into its own function. This should make it easy
  # to switch out the underlying dataset
  rValue = (d) -> parseInt(d.count)

  # function to define the 'id' of a data element
  #  - used to bind the data uniquely to the force nodes
  #   and for url creation
  #  - should make it easier to switch out dataset
  #   for your own
  idValue = (d) -> d.name

  # function to define what to display in each bubble
  #  again, abstracted to ease migration to
  #  a different dataset if desired
  textValue = (d) -> d.name

  # constants to control how
  # collision look and act
  collisionPadding = 6
  minCollisionRadius = 12


  # variables that can be changed
  # to tweak how the force layout
  # acts
  # - jitter controls the 'jumpiness'
  #  of the collisions
  jitter = 0.5

  # ---
  # tweaks our dataset to get it into the
  # format we want
  # - for this dataset, we just need to
  #  ensure the count is a number
  # - for your own dataset, you might want
  #  to tweak a bit more
  # ---
  transformData = (rawData) ->
    rawData.forEach (d) ->
      d.count = parseInt(d.count)
      rawData.sort(() -> 0.5 - Math.random())
    rawData

  # ---
  # tick callback function will be executed for every
  # iteration of the force simulation
  # - moves force nodes towards their destinations
  # - deals with collisions of force nodes
  # - updates visual bubbles to reflect new force node locations
  # ---
  tick = (e) ->
    dampenedAlpha = e.alpha * 0.1
    
    # Most of the work is done by the gravity and collide
    # functions.
    # node
      # .each(gravity(dampenedAlpha))
      # .each(collide(jitter))

    if split
      node.each(split_force(dampenedAlpha))
    else
      node.each(together(dampenedAlpha))


    node.attr("transform", (d) -> "translate(#{d.x},#{d.y})")

    # As the labels are created in raw html and not svg, we need
    # to ensure we specify the 'px' for moving based on pixels
    label
      .style("left", (d) -> ((margin.left + d.x) - d.dx / 2) + "px")
      .style("top", (d) -> ((margin.top + d.y) - d.dy / 2) + "px")

  # The force variable is the force layout controlling the bubbles
  # here we disable gravity and charge as we implement custom versions
  # of gravity and collisions for this visualization
  force = d3.layout.force()
    .gravity(grav)
    .friction(0.9)
    .charge(charge)
    .size([width, height])
    .on("tick", tick)

  # ---
  # Creates new chart function. This is the 'constructor' of our
  #  visualization
  # Check out http://bost.ocks.org/mike/chart/ 
  #  for a explanation and rational behind this function design
  # ---
  chart = (selection) ->
    selection.each (rawData) ->

      # first, get the data in the right format
      data = transformData(rawData)
      # setup the radius scale's domain now that
      # we have some data
      maxDomainValue = d3.max(data, (d) -> rValue(d))
      rScale.domain([0, maxDomainValue])

      # a fancy way to setup svg element
      svg = d3.select(this).selectAll("svg").data([data])
      svgEnter = svg.enter().append("svg")
      svg.attr("width", width + margin.left + margin.right )
      svg.attr("height", height + margin.top + margin.bottom )
      
      # node will be used to group the bubbles
      node = svgEnter.append("g").attr("id", "bubble-nodes")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

      # clickable background rect to clear the current selection
      node.append("rect")
        .attr("id", "bubble-background")
        .attr("width", width)
        .attr("height", height)
        .on("click", clear)

      # label is the container div for all the labels that sit on top of 
      # the bubbles
      # - remember that we are keeping the labels in plain html and 
      #  the bubbles in svg
      label = d3.select(this).selectAll("#bubble-labels").data([data])
        .enter()
        .append("div")
        .attr("id", "bubble-labels")

      update()

      # see if url includes an id already 
      hashchange()

      # automatically call hashchange when the url has changed
      d3.select(window)
        .on("hashchange", hashchange)

  # ---
  # update starts up the force directed layout and then
  # updates the nodes and labels
  # ---
  update = () ->
    # add a radius to our data nodes that will serve to determine
    # when a collision has occurred. This uses the same scale as
    # the one used to size our bubbles, but it kicks up the minimum
    # size to make it so smaller bubbles have a slightly larger
    # collision 'sphere'
    data.forEach (d,i) ->
      d.forceR = Math.max(minCollisionRadius, rScale(rValue(d)))

    # start up the force layout
    force.nodes(data).start()

    # call our update methods to do the creation and layout work
    updateNodes()
    updateLabels()

  # ---
  # updateNodes creates a new bubble for each node in our dataset
  # ---
  updateNodes = () ->
    # here we are using the idValue function to uniquely bind our
    # data to the (currently) empty 'bubble-node selection'.
    # if you want to use your own data, you just need to modify what
    # idValue returns
    node = node.selectAll(".bubble-node").data(data, (d) -> idValue(d))

    # we don't actually remove any nodes from our data in this example 
    # but if we did, this line of code would remove them from the
    # visualization as well
    node.exit().remove()

    # nodes are just links with circles inside.
    # the styling comes from the css
    node.enter()
      .append("a")
      .attr("class", "bubble-node")
      .attr("xlink:href", (d) -> "##{encodeURIComponent(idValue(d))}")
      .call(force.drag)
      .call(connectEvents)
      .append("circle")
      .attr("r", (d) -> rScale(rValue(d)))
      .attr("fill", (d) -> if d.category == 'other' then "rgb(192, 226, 230)" else 'rgb(255, 111, 64)')

  # ---
  # updateLabels is more involved as we need to deal with getting the sizing
  # to work well with the font size
  # ---
  updateLabels = () ->
    # as in updateNodes, we use idValue to define what the unique id for each data 
    # point is
    label = label.selectAll(".bubble-label").data(data, (d) -> idValue(d))

    label.exit().remove()

    # labels are anchors with div's inside them
    # labelEnter holds our enter selection so it 
    # is easier to append multiple elements to this selection
    labelEnter = label.enter().append("a")
      .attr("class", "bubble-label")
      .attr("href", (d) -> "##{encodeURIComponent(idValue(d))}")
      .call(force.drag)
      .call(connectEvents)

    labelEnter.append("div")
      .attr("class", "bubble-label-name")
      .text((d) -> textValue(d))

    labelEnter.append("div")
      .attr("class", "bubble-label-value")
      .text((d) -> rValue(d))

    # label font size is determined based on the size of the bubble
    # this sizing allows for a bit of overhang outside of the bubble
    # - remember to add the 'px' at the end as we are dealing with 
    #  styling divs
    label
      .style("font-size", (d) -> Math.max(8, rScale(rValue(d) / 2)) + "px")
      .style("width", (d) -> 2.5 * rScale(rValue(d)) + "px")

    # interesting hack to get the 'true' text width
    # - create a span inside the label
    # - add the text to this span
    # - use the span to compute the nodes 'dx' value
    #  which is how much to adjust the label by when
    #  positioning it
    # - remove the extra span
    label.append("span")
      .text((d) -> textValue(d))
      .each((d) -> d.dx = Math.max(2.5 * rScale(rValue(d)), this.getBoundingClientRect().width))
      .remove()

    # reset the width of the label to the actual width
    label
      .style("width", (d) -> d.dx + "px")
  
    # compute and store each nodes 'dy' value - the 
    # amount to shift the label down
    # 'this' inside of D3's each refers to the actual DOM element
    # connected to the data node
    label.each((d) -> d.dy = this.getBoundingClientRect().height)

  together = (alpha) ->
    center = {x: width / 2, y:(height / 2) - 20}
    (d) ->
      d.x = d.x + (center.x - d.x) * alpha
      d.y = d.y + (center.y - d.y) * alpha

  split_force = (alpha) ->
    (d) ->
      center = centers[d.category]
      if !center
        center = centers['other']
      d.x = d.x + (center.x - d.x) * alpha
      d.y = d.y + (center.y - d.y) * alpha

  # ---
  # custom gravity to skew the bubble placement
  # ---
  gravity = (alpha) ->
    # start with the center of the display
    cx = width / 2
    cy = height / 2
    # use alpha to affect how much to push
    # towards the horizontal or vertical
    ax = alpha / 8
    ay = alpha

    # return a function that will modify the
    # node's x and y values
    (d) ->
      d.x += (cx - d.x) * ax
      d.y += (cy - d.y) * ay

  # ---
  # custom collision function to prevent
  # nodes from touching
  # This version is brute force
  # we could use quadtree to speed up implementation
  # (which is what Mike's original version does)
  # ---
  collide = (jitter) ->
    # return a function that modifies
    # the x and y of a node
    (d) ->
      data.forEach (d2) ->
        # check that we aren't comparing a node
        # with itself
        if d != d2
          # use distance formula to find distance
          # between two nodes
          x = d.x - d2.x
          y = d.y - d2.y
          distance = Math.sqrt(x * x + y * y)
          # find current minimum space between two nodes
          # using the forceR that was set to match the 
          # visible radius of the nodes
          minDistance = d.forceR + d2.forceR + collisionPadding

          # if the current distance is less then the minimum
          # allowed then we need to push both nodes away from one another
          if distance < minDistance
            # scale the distance based on the jitter variable
            distance = (distance - minDistance) / distance * jitter
            # move our two nodes
            moveX = x * distance
            moveY = y * distance
            d.x -= moveX
            d.y -= moveY
            d2.x += moveX
            d2.y += moveY

  # ---
  # adds mouse events to element
  # ---
  connectEvents = (d) ->
    d.on("click", click)
    # d.on("mouseover", mouseover)
    # d.on("mouseout", mouseout)

  # ---
  # clears currently selected bubble
  # ---
  clear = () ->
    location.replace("#")

  # ---
  # changes clicked bubble by modifying url
  # ---
  click = (d) ->
    location.replace("#" + encodeURIComponent(idValue(d)))
    d3.event.preventDefault()

  # ---
  # called when url after the # changes
  # ---
  hashchange = () ->
    id = decodeURIComponent(location.hash.substring(1)).trim()
    updateActive(id)

  # ---
  # activates new node
  # ---
  updateActive = (id) ->
    node.classed("bubble-selected", (d) -> id == idValue(d))
    # if no node is selected, id will be empty
    if id.length > 0
      d3.select("#status").html("<h3>The word <span class=\"active\">#{id}</span> is now active</h3>")
    else
      d3.select("#status").html("<h3>No word is active</h3>")

  # ---
  # hover event
  # ---
  mouseover = (d) ->
    node.classed("bubble-hover", (p) -> p == d)
    console.log(idValue(d))

  # ---
  # remove hover class
  # ---
  mouseout = (d) ->
    node.classed("bubble-hover", false)

  # ---
  # public getter/setter for jitter variable
  # ---
  chart.jitter = (_) ->
    if !arguments.length
      return jitter
    jitter = _
    force.start()
    chart

  # ---
  # public getter/setter for height variable
  # ---
  chart.height = (_) ->
    if !arguments.length
      return height
    height = _
    chart

  # ---
  # public getter/setter for width variable
  # ---
  chart.width = (_) ->
    if !arguments.length
      return width
    width = _
    chart

  # ---
  # public getter/setter for radius function
  # ---
  chart.r = (_) ->
    if !arguments.length
      return rValue
    rValue = _
    chart

  chart.toggle = (_) ->
    split = !split

    force.start()
  
  # final act of our main function is to
  # return the chart function we have created
  return chart

BubblePlot = () ->

  width = 235
  height = 200
  world_plot = null
  radius = d3.scale.sqrt()
    .domain([0, 1e6])
    .range([3, (width / 2) - 40])
  div = null

  click = (d) ->
    world_plot.center([d.lon, d.lat])

  chart = (selection) ->
    selection.each (rawData) ->

      rawData = rawData.filter((d,i) -> d.region and d.local).filter((d,i) -> i < 16)

      data = rawData
      count_extent = d3.extent(data, (d) -> +d.count)
      radius.domain(count_extent)

      div = d3.select(this).data([data])


      bubble = div.selectAll(".bubble")
        .data(data)
        .enter().append("div")
        .attr("class", "bubble")

      bubble.append("h2")
        .text((d) -> prettyName(d))

      bubble.append("h3")
        .attr("class", "tweet_count")
        .text((d) -> "#{commaSeparateNumber(d.count)} tweets")

      svg = bubble.append("svg")
        .attr("width", width)
        .attr("height", height)
        .attr("position", "absolute")

      svg.append("circle")
        .attr("cx", width / 2)
        .attr("cy", height / 2)
        .attr("r", (d) -> radius(+d.count))
        .attr("class", "circle")
        .on("click", click)

  chart.world = (_) ->
    if !arguments.length
      return world_plot
    world_plot = _
    chart

  return chart

WorldPlot = () ->
  width = 940
  height = 600
  data = []
  svg = null
  g = null
  points = null

  margin = {top: 20, right: 20, bottom: 20, left: 20}
  mworld = null

  radius = d3.scale.sqrt()
    .domain([0, 1e6])
    .range([2, 18])

  projection = d3.geo.mercator()
    .scale(170)
    .rotate([30,0])
    .translate([width / 2, height / 2])
    .precision(.1)

  # getRadius = (d,i) ->
  #   console.log(d)
  #   3

  path = d3.geo.path()
    .projection(projection)
    # .pointRadius(getRadius)

  graticule = d3.geo.graticule()

  xScale = d3.scale.linear().domain([0,10]).range([0,width])
  yScale = d3.scale.linear().domain([0,10]).range([0,height])
  xValue = (d) -> parseFloat(d.x)
  yValue = (d) -> parseFloat(d.y)

  reset = () ->
    g.transition().duration(750).attr("transform", "")


  click = (d) ->
    b = path.bounds(d)

    g.transition().duration(750).attr("transform",
      "translate(" + projection.translate() + ")"
      + "scale(" + .95 / Math.max((b[1][0] - b[0][0]) / width, (b[1][1] - b[0][1]) / height) + ")"
      + "translate(" + -(b[1][0] + b[0][0]) / 2 + "," + -(b[1][1] + b[0][1]) / 2 + ")")


  redraw = () ->
    console.log('redraw')
    g.attr("transform", "translate(" + d3.event.translate + ")scale(" + d3.event.scale + ")")



  chart = (selection) ->
    selection.each (rawData) ->

      rawData = rawData.filter((d) -> d.country ).filter (d) -> +d.count > 5

      data = rawData

      count_extent = d3.extent(data, (d) -> +d.count)
      radius.domain(count_extent)
      console.log(count_extent)

      svg = d3.select(this).selectAll("svg").data([data])
      svg.enter().append("svg")

      svg
        .attr("width", width)
        .attr("height", height)
        # .call(d3.behavior.zoom())
        # .on("zoom", redraw)

      svg.append("defs").append("path")
        .datum({type: "Sphere"})
        .attr("id", "sphere")
        .attr("d", path)

      svg.append("use")
        .attr("class", "stroke")
        .attr("xlink:href", "#sphere")

      svg.append("use")
        .attr("class", "fill")
        .attr("xlink:href", "#sphere")

      g = svg.append("g")

      g.append("rect")
        .attr("class", "cover")
        .attr("width", width)
        .attr("height", height)
        # .call(d3.behavior.zoom())
        # .on("zoom", redraw)


      g.append("path")
        .datum(graticule)
        .attr("class", "graticule")
        .attr("d", path)

      g.insert("path", ".graticule")
        .datum(topojson.feature(mworld, mworld.objects.land))
        .attr("class", "land")
        .attr("d", path)

      g.insert("path", ".graticule")
        .datum(topojson.mesh(mworld, mworld.objects.countries, (a, b) -> a != b))
        .attr("class", "boundary")
        .attr("d", path)

      
      # svg.attr("width", width + margin.left + margin.right )
      # svg.attr("height", height + margin.top + margin.bottom )

      # g = svg.select("g")
      #   .attr("transform", "translate(#{margin.left},#{margin.top})")

      points = g.append("g").attr("id", "vis_points")
      update()


  update = () ->
    # points.append("path")
    #   .datum({type: "LineString", coordinates: [[-77.05, 38.91], [56.35, 39.91]]})
    #   .attr("class", "route")
    #   .attr("stroke-width", 20)
    #   .attr("d", path)


    # reverse to plot biggest last
    coords = getCoords(data).reverse()
    # points.append("path")
    #   .datum({type: "FeatureCollection", features:coords})
    #   .attr("class", "points")
    #   .attr("d", path.pointRadius((d,i) -> radius(data[i].count)))
    #
    points.selectAll(".hidden_symbol")
      .data(coords)
    .enter().append("path")
      .attr("class", "hidden_symbol")
      .attr("d", path.pointRadius((d,i) -> Math.max(radius(+d.properties.count), 10) ))

    points.selectAll(".symbol")
      .data(coords)
    .enter().append("path")
      .attr("class", "symbol")
      .attr("d", path.pointRadius((d,i) -> radius(+d.properties.count) ))

    $('svg .hidden_symbol, svg .symbol').tipsy({
      gravity:'w'
      html:true
      title: () ->
        d = this.__data__
        "<strong>#{prettyName(d.properties)}</strong> <i>#{commaSeparateNumber(d.properties.count)} tweets</i>"
    })

  chart.center = (point) ->
    console.log(point)
    g.attr("transform", "translate(" + d3.event.translate + ")scale(" + d3.event.scale + ")")
    # g.transition().duration(750).attr("transform",
    #   "translate(" + projection.translate() + ")"
    #     + "scale(2)"
    #     + "translate()")
      # + "scale(" + .95 / (point[1] - point[0]) / width + ")"
      # + "translate(" + -point[1] + "," + -point[0]+ ")")


  chart.reset = () ->
    g.transition().duration(750).attr("transform", "")

  chart.height = (_) ->
    if !arguments.length
      return height
    height = _
    chart

  chart.width = (_) ->
    if !arguments.length
      return width
    width = _
    chart

  chart.margin = (_) ->
    if !arguments.length
      return margin
    margin = _
    chart

  chart.x = (_) ->
    if !arguments.length
      return xValue
    xValue = _
    chart

  chart.y = (_) ->
    if !arguments.length
      return yValue
    yValue = _
    chart

  chart.world = (_) ->
    if !arguments.length
      return mworld
    mworld = _
    chart

  return chart

root.WorldPlot = WorldPlot

root.plotData = (selector, data, world, plot) ->
  plot.world(world)
  d3.select(selector)
    .datum(data)
    .call(plot)



$ ->

  plot = WorldPlot()
  bubbles = BubblePlot()
  moves = MoveBubbles()
  bubbles.world(plot)
  display = (error, data, top_data, world) ->
    plotData("#vis", data, world, plot)

    d3.select("#bubbles")
      .datum(data)
      .call(bubbles)

    d3.select("#move_bubbles")
      .datum(top_data)
      .call(moves)

  queue()
    # .defer(d3.csv, "data/all_with_users_position.csv")
    .defer(d3.csv, "data/mbfw_position_aggregate.csv")
    .defer(d3.csv, "data/top_mbfw_cat.csv")
    .defer(d3.json, "data/world-50m.json")
    .await(display)

  toggleMoves = (t) ->
    moves.toggle()
    

  $('#view_selection a').click () ->
    view_type = $(this).attr('id')
    $('#view_selection a').removeClass('active')
    $(this).toggleClass('active')
    toggleMoves(view_type)
    return false
    
