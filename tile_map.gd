extends TileMap

var debug = {
	"click_locations":false,
	"show_mines":false
}

#Timer stuff
var timer
var time = 0
var timer_started


#Game stuff
var remaining_mines
var minefield = []
var mine_count = 60
var flag_count = 0
var grid_size = 20
var game_over

enum SquareState {
	COVERED, UNCOVERED, FLAGGED_MINE, FLAGGED_NO_MINE, COVERED_MINE
}


# Called when the node enters the scene tree for the first time.
func _ready():	
	timer = get_node("Timer")
	
	remaining_mines = get_node("RemainingMines")
	remaining_mines.add_theme_color_override("font_color", Color(0, 0, 0))
	
	get_node("Reset").pressed.connect(self.reset)
	setup_board()
	
	pass # Replace with function body.

func setup_board()->void:
	randomize()
	minefield = []
	remaining_mines.set_text(str(mine_count))
	flag_count = 0
	game_over = false
	
	timer_started = false
	
	for i in range(grid_size):
		minefield.append([])
		for j in range(grid_size):
			minefield[i].append(SquareState.COVERED);
			set_cell(0, Vector2i(i, j), 0, Vector2i(8, 0))
	
	var i = 0
	var x=0
	var y=0
	while i<mine_count:
		x = randi()%grid_size
		y = randi()%grid_size
		if minefield[x][y]!=SquareState.COVERED_MINE:
			if debug.show_mines:
				minefield[x][y]=SquareState.FLAGGED_MINE
				set_cell(0, Vector2i(x, y), 0, Vector2i(9, 0))
			else:
				minefield[x][y]=SquareState.COVERED_MINE
			
			i+=1
	pass

func reset()->void:
	setup_board()
	time = 0
	timer.set_text("0")
	pass

func _input(event):
	var pos = Vector2i(event.position-self.position)/32
	var x = pos.x
	var y = pos.y
	if not game_over and event is InputEventMouseButton and event.is_pressed() and within_borders(x, y): # Only responding to mouse presses
		if event.button_index == MOUSE_BUTTON_LEFT:
			timer_started = true #Timer starts, and then remains on
			
			try_reveal(x, y)
			pass
		
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Setting flags with weird Godot switch substitute
			match minefield[x][y]:
				SquareState.COVERED_MINE:
					minefield[x][y] = SquareState.FLAGGED_MINE
					update_flag_count(1)
					set_cell(0, Vector2i(x, y), 0, Vector2i(9, 0))
				SquareState.FLAGGED_MINE:
					minefield[x][y] = SquareState.COVERED_MINE
					update_flag_count(-1)
					set_cell(0, Vector2i(x, y), 0, Vector2i(8, 0))
				SquareState.COVERED:
					minefield[x][y] = SquareState.FLAGGED_NO_MINE
					update_flag_count(1)
					set_cell(0, Vector2i(x, y), 0, Vector2i(9, 0))
				SquareState.FLAGGED_NO_MINE:
					minefield[x][y] = SquareState.COVERED
					update_flag_count(-1)
					set_cell(0, Vector2i(x, y), 0, Vector2i(8, 0))
				#Revealing extra squares around numbered tiles
				SquareState.UNCOVERED:
					if count_flags(x, y) == count_mines(x, y):
						for j in range(3):
							for k in range(3):
								if within_borders(x+j-1,y+k-1):
									try_reveal(x+j-1,y+k-1)
						pass
					elif count_flags(x, y) < count_mines(x, y): #Briefly flash potential mine spots
						for j in range(3):
							for k in range(3):
								if within_borders(x+j-1,y+k-1) and minefield[x+j-1][y+k-1] in [SquareState.COVERED, SquareState.COVERED_MINE]:
									set_cell(0, Vector2i(x+j-1,y+k-1), 0, Vector2i(0, 0))
						pass
					pass
			pass
		pass
	
	if not game_over and event is InputEventMouseButton and not event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT and within_borders(x, y): #Unflashing potential mine spots
		for j in range(3):
			for k in range(3):
				if within_borders(x+j-1,y+k-1) and minefield[x+j-1][y+k-1] in [SquareState.COVERED, SquareState.COVERED_MINE]:
					set_cell(0, Vector2i(x+j-1,y+k-1), 0, Vector2i(8, 0))
		pass
	
	if event is InputEventMouseButton and not event.is_pressed() and debug.click_locations:
		print("mouse button event at ", position, event.button_index)

func count_mines(x:int, y:int)->int:
	var i = 0
	for j in range(3):
		for k in range(3):
			if within_borders(x+j-1, y+k-1) and (minefield[x+j-1][y+k-1] == SquareState.COVERED_MINE or minefield[x+j-1][y+k-1] == SquareState.FLAGGED_MINE):
				i+=1
	return i

func count_flags(x:int, y:int)->int: #Might have to tweak this function, only counting false flags
	var i = 0
	for j in range(3):
		for k in range(3):
			if within_borders(x+j-1, y+k-1) and (minefield[x+j-1][y+k-1] == SquareState.FLAGGED_MINE or minefield[x+j-1][y+k-1] == SquareState.FLAGGED_NO_MINE):
				i+=1
	return i

func try_reveal(x:int, y:int)->void:
	if minefield[x][y]==SquareState.COVERED:
		var m = count_mines(x, y)
		set_cell(0, Vector2i(x, y), 0, Vector2i(m, 0))
		minefield[x][y]=SquareState.UNCOVERED
		if m==0:
			for j in range(3):
				for k in range(3):
					if within_borders(x+j-1,y+k-1):
						try_reveal(x+j-1,y+k-1)
		pass
	
	if minefield[x][y]==SquareState.COVERED_MINE: #Game over
		set_cell(0, Vector2i(x, y), 0, Vector2i(11, 0))
		end_game()
		#More game over stuff
		pass
	pass

func update_flag_count(i:int)->void:
	flag_count += i
	remaining_mines.set_text(str(mine_count-flag_count))
	
	#Check game over
	if flag_count == mine_count:
		game_over = true
		
		for j in range(grid_size):
			for k in range(grid_size):
				if minefield[j][k]==SquareState.FLAGGED_NO_MINE:
					game_over=false
				pass
		
		if game_over:
			end_game()
		pass
	pass

func within_borders(x:int, y:int)->bool:
	return x>=0 and x<grid_size and y>=0 and y<grid_size

func end_game()->void:
	game_over = true
	timer_started = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if int(time)<int(time+delta) and int(time+delta)<1000:
		timer.set_text(str(int(time+delta)))
	
	if timer_started:
		time+=delta
	pass
