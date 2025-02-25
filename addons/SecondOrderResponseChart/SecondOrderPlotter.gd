@tool
extends EditorProperty
class_name SecondOrderPlotter

var margin:float =.4 # in chart vertical margin
var left_offset:int = 25 #offset of chart on the left
var viewport_height:float
var viewport_width:float
var corners:Array 
var viewport_limits:Array

var command_color:Color = Color.RED
var output_color:Color = Color.DARK_GREEN

var weights:Dictionary = {"k":1,"wo":40,"xi":1,"z":0}
var global_delta:float = .016
var command_array:Array[Vector2] = []
var response_array:Array[Vector2] = []

var chart_plotter:LineChartPlotter
var chart_container:Control
var response_time_label:Label

func add_graph_response_time() -> HBoxContainer:
	var parent:HBoxContainer = HBoxContainer.new()
	var text:Label = Label.new()
	response_time_label = Label.new()
	var end_text:Label = Label.new()
	parent.add_child(text)
	parent.add_child(response_time_label)
	parent.add_child(end_text)
	
	text.text = "Response time approximation: "
	response_time_label.text = "0"
	end_text.text = "s"
	return parent

func _init() -> void:
	var parent:VBoxContainer = VBoxContainer.new()
	chart_plotter = LineChartPlotter.new()
	chart_container = Control.new()
	parent.add_child(chart_container)
	parent.add_child(add_graph_response_time())
	add_child(parent)
	set_command_step()

func _ready() -> void:
	update_graph_size()
	EditorInterface.get_inspector().resized.connect(update_graph_size)

func update_graph_size() -> void:
	var inspector_size:Vector2 = EditorInterface.get_inspector().size
	
	# not custom_minimum_size.x because can't reduce size and crash if too big
	chart_container.custom_minimum_size.y = inspector_size.x / 1.6 - left_offset
	chart_container.size.y = chart_container.custom_minimum_size.y
	
	viewport_width = chart_container.size.y * 1.6 
	viewport_height = chart_container.size.y
	
	viewport_limits = [Vector2(0, 0),
		Vector2(viewport_width,viewport_height)]
	corners = [Vector2(0, 0),
			Vector2(viewport_width, 0),
			Vector2(viewport_width,viewport_height),
			Vector2(0,viewport_height),
			Vector2(0, 0)]

func _physics_process(delta:float) -> void:
	global_delta = delta

func _draw() -> void:
	var editor_settings:EditorSettings = EditorInterface.get_editor_settings()
	var bg_color:Color = editor_settings.get_setting("text_editor/theme/highlighting/background_color")
	var border_color:Color = editor_settings.get_setting("text_editor/theme/highlighting/text_color")
	
	var graph_height:float = viewport_height*(1-margin)
	var graph_width:float = viewport_width

	
	var viewported:Dictionary = chart_plotter.auto_viewporter(command_array,
			graph_height,graph_width,margin)
	@warning_ignore("unsafe_call_argument")
	var response:Array = chart_plotter.adapt_viewporter(response_array,
			viewported["ratios"],viewported["offsets"],viewport_limits)
			
	draw_colored_polygon(corners,bg_color)
	@warning_ignore("unsafe_call_argument")
	draw_polyline(viewported["viewported_values"],command_color,4)
	draw_polyline(response,output_color,3)
	draw_polyline(corners,border_color,2)

func set_command_step() -> void:
	command_array = chart_plotter.vect_step(5,100,10)

func set_command_detailled() -> void:
	command_array = chart_plotter.vect_command(5,500)

func plot_array_response() -> void:
	var second_order:SecondOrderSystem = SecondOrderSystem.new(weights)
	response_array = [Vector2.ZERO]
	for i:int in range(1,command_array.size()):
		var output:Dictionary = second_order.vec2_second_order_response(global_delta,command_array[i],response_array[i-1])
		response_array.append(output["output"])
		
	# needed fot plotting because second order modified y 
	for i:int in range(0,response_array.size()):
		response_array[i][0]=i
	response_time_label.text = str(round(get_temps_95()*1000)/1000)
	queue_redraw()

func update_chart_weights(new_weights:Dictionary) -> void:
	for key:String in new_weights:
		weights[key] = new_weights[key]
	plot_array_response()

func update_chart_type(chart_type_ID:int) -> void:
	if chart_type_ID == 0: set_command_step()
	elif chart_type_ID == 1: set_command_detailled()
	plot_array_response()

func get_temps_95() -> float:
	if weights["xi"] > 1:return (3/weights["wo"])
	else: return (3/(weights["wo"]*weights["xi"]))
