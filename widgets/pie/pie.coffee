class Dashing.Pie extends Dashing.Widget
  @accessor 'value'

  onData: (data) ->
    @render(data.items)
  
  render: (data) ->
    if(!data)
      data = @get("items")
    if(!data)
        return

    width = 250    
    height = 250   
    radius = 125   
    label_radius = 110
    color = d3.scale.category20()

    $(@node).children("svg").remove();

    chart = d3.select(@node).append("svg:svg")
        .data([data])
        .attr("width", width)
        .attr("height", height)
      .append("svg:g")
        .attr("transform", "translate(#{radius} , #{radius})")

    #
    # Center label
    #
    label_group = chart.append("svg:g")
      .attr("dy", ".35em")

    center_label = label_group.append("svg:text")
      .attr("class", "chart_label")
      .attr("text-anchor", "middle")
      .attr("fill", "#FFF")
      .text(@get("title"))
    
    arc = d3.svg.arc().innerRadius(radius * .6).outerRadius(radius)
    pie = d3.layout.pie().value((d) -> d.value)

    arcs = chart.selectAll("g.slice")
      .data(pie)
      .enter()
      .append("svg:g")
      .attr("class", "slice")

    arcs.append("svg:path")
      .attr("fill", (d, i) -> color(i))
      .attr("d", arc)

    #
    # Legend
    #
    legend = d3.select(@node).append("svg:svg")
      .attr("class", "legend")
      .attr("x", 0)
      .attr("y", 0)
      .attr("height", 300)
      .attr("width", 200)
    
    legend.selectAll("g").data(data)
      .enter()
      .append("g")
      .each((d, i) ->
        g = d3.select(this)

        row = i % 10
        col = parseInt(i / 10)

        g.append("rect")
          .attr("x", col * 100)  
          .attr("y", row * 30)   
          .attr("width", 20)     
          .attr("height", 20)    
          .attr("fill", color(i))

        console.log "wat"
        g.append("text")
          .attr("x", (col * 100) + 30) 
          .attr("y", (row + 1) * 30 - 12)
          .attr("font-size", "20px")
          .attr("height", 60)
          .attr("width", 150)
          .attr("fill", "#FFF")
          .text(data[i].label)
      )
