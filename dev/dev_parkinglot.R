
```{r}
gate_or = function(fill = "white", color = "black", size = 2, stroke = 1, alpha = 1){
  # Draw the design for an OR gate
  dat = tibble(
    # Set starting point
    from = 0,
    # Set ending point
    to = size,
    # Get midpoint
    midpoint = (from + to) / 2,
    # Get number of intervals
    n = 100,
    # use to create the intervals
    by = abs(from - to) / n) %>%
    # 
    summarize(
      # First, calculate the coordinates for the left hand side
      xleft = seq(from = from, to = midpoint, length.out = n),
      # Second, calculate the right hand side!
      xright = seq(from = midpoint, to = to, length.out = n),
      # Finally, retain the end point
      xmax = to) %>%
    pivot_longer(
      cols = -c("xmax"),
      names_to = c(".value", "direction"),
      names_pattern = c("(x)(left|right)")) %>%
    expand_grid(bound = c("lower", "upper")) %>%
    group_by(direction, bound) %>%
    summarize(
      x = x,
      y = case_when(
        direction == "left" & bound == "lower" ~ 1/xmax*sqrt(x),
        direction == "left" & bound == "upper" ~ xmax*sqrt(x),
        direction == "right" & bound == "lower" ~ 1/xmax*sqrt(xmax - x),
        direction == "right" & bound == "upper" ~ xmax*sqrt(xmax - x)))
  
  dat %>%
    pivot_wider(id_cols = c(x, direction), names_from = bound, values_from = y) %>%
    ggplot(mapping = aes(x = x, ymin = lower, ymax = upper)) +
    geom_ribbon(fill = fill, color = color, size = stroke, alpha = alpha) +
    coord_fixed(ratio = 1) +
    theme_void(base_size = 14) %>%
    return()
}

g = gate_or(fill = "grey", color = "black", size = 2, stroke = 1)
# Initialize a temporary file
tmp = tempfile()
# Save our ggplot image to file as an SVG
ggsave(filename = tmp, plot = g, device = "svg", units = "px", width = 10, height = 10)
# Resave from normal SVG to Cairo SVG
rsvg_svg(svg = tmp, file = tmp)
# Read Cairo SVG to Picture object
gp <- grImport2::readPicture(file = tmp)

#symbolize(gp, x = 1, y = 1, size = 0.3, units = "npc")
gp
```


```{r}
library(tidyverse)
library(tidyfault)
data(fakeedges)
data(fakenodes)
gg = illustrate(nodes = fakenodes, edges = fakeedges, type = "both", node_key = "id", layout = "tree")

plot = ggplot() +
  geom_line(data = gg$edges, mapping = aes(x = x, y = y, group = edge_id)) +
  geom_point(data = gg$nodes, mapping = aes(x = x, y = y), size = 5)

help("+.gg")
```

```{r}
format_data = function(data, mapping = aes(x, y, gate), fill = "white", color = "black", size = 2, stroke = 1){
  
  d = tibble(
    x = data$x,
    y = data$y,
    gate = data$type,
    fill = fill,
    color = color, 
    size = size,
    stroke = stroke)
  
  slices = d %>% 
    select(gate, fill, color, size, stroke) %>%
    distinct() %>%
    mutate(group = 1:n())
  
  
  d = d %>%
    left_join(by = c("gate", 'fill', 'color', 'size', 'stroke'),
              y = slices)
  
  return(d)
}

get_symbols = function(subset){
  
  myset = subset %>% 
    select(gate, fill, color, size, stroke, group) %>%
    distinct()
  
  # Make ggplot of the gate
  g = gate_or(fill = myset$fill, color = myset$color, size = myset$size, stroke = myset$stroke)
  # Initialize a temporary file
  tmp = tempfile()
  # Save our ggplot image to file as an SVG
  ggsave(filename = tmp, plot = g, device = "svg", units = "px", width = 10, height = 10)
  # Resave from normal SVG to Cairo SVG
  rsvg_svg(svg = tmp, file = tmp)
  # Read Cairo SVG to Picture object
  picture <- grImport2::readPicture(file = tmp)
  
  # Gather the data...
  gsym = subset %>% 
    # Get the symbols at the specified coordinates!
    with(  
      symbolsGrob(
        picture = picture,
        x = scales::rescale(x),
        y = scales::rescale(y),
        default.units = "npc",
        size = size) )
  
  gsym %>%
    return()
}



geom_gate = function(data){
  
  d = format_data(data = data)
  
  xlim = range(d$x, na.rm = TRUE)
  ylim = range(d$y, na.rm = TRUE)
  
  
  mysymbols = d %>%
    split(.$group) %>%
    map(~get_symbols(.), .id = "group")
  
  paste("mysymbols[[", 1:length(mysymbols), "]]") %>%
    paste("annotation_custom(grob = ", .,  
          ", xmin = ", xlim[1], ", xmax = ", xlim[2],
          ", ymin = ", ylim[1], ", ymax = ", ylim[2], ")",
          sep = "") %>%
    paste(collapse = " + ") %>%
    paste("ggplot() + ", ., "+ coord_cartesian(", 
          " xlim = ", "c(", xlim[1], ", ", xlim[2], "), ", 
          " ylim = ", "c(", ylim[1], ", ", ylim[2], "), ",
          "expand = FALSE)") %>%
    parse(text = .) %>%
    eval() %>%
    return()
  
}

x = geom_gate(data = gg$nodes %>%
                filter(type == "or"))

```

Path of least resistance:
  
  Add gates, no legend.

Add gates, with legend.

Add gates and points, with legend.

```{r}
# Get basic plot coordinates
data = tibble(x = 1:5,
              y = 1:5) %>%
  ggplot(mapping = aes(x = x, y = y))

# Get symbols at coordinates
gs = data$data %>%
  with()

```


```{r}
library(rsvg)


# Let's write a function to get a series of color squares
color_square = function(fill, width = 100, height = 100){
  sq = function(fill){ image_blank(color = fill, width = width, height = height) }
  
  a = sq(fill = fill[1])
  n = length(fill)
  if(n > 1){
    for(i in 2:n){
      a = c(a, sq(fill[i]))
    }
    a = image_append(a, stack = FALSE)
  }
  return(a)
}

cols = c("black", "blue") %>% color_square() 



g = image_read_svg("images/or.svg") %>%
  image_transparent(color = "white")  
library(ggimage)
tibble(x = 1:10, 
       y = 1:10) %>%
  ggplot(mapping = aes(x = x, y = y)) +
  geom_image(mapping = aes(image = "images/or.svg")) +
  coord_fixed(ratio = 1)

#install.packages('grImport')
#install.packages("grImport2")
library(grImport2)

file <- system.file("SVG", "images/or.svg", package="grImport2")
img = readPicture(file)
file
symbolsGrob(img,
            x=rescale(d$x,from=xlims),
            y=rescale(d$y,from=ylims),
            default.units="npc",
            size=0.3)
```












