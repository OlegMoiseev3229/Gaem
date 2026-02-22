package main
import "core:os"
import "core:math"
import sdl "vendor:sdl2"
import sdl_image "vendor:sdl2/image"

//TYPES 
GameState :: enum {
	TitleScreen,
	Game,
	ShowEnemies,
	CreateLevel,
}

Id_t :: enum {
	TextureMissing,
	//UI
	TheButton,
	GameBG,
	TitleScreen,
	TitleScreenBlank,
	StartButton,
	ShowEnemiesButton,
	PreviousEnemyButton,
	NextEnemyButton,
	EnemySelection,
	CreateLevelButton,
	//Numbers
	Number0,
	Number1,
	Number2,
	Number3,
	Number4,
	Number5,
	Number6,
	Number7,
	Number8,
	Number9,
	//Enemies
	SmallGuy,
	BiggerGuy
}

ImageData :: struct {
	id: Id_t,
	data: []u8
}

EnemyType :: enum {
	SmallGuy,
	BiggerGuy,
	MaxEnemyType
}

EnemyTypeData :: struct {
	name: string,
	default_hp: int,
	texture_size: [2]int,
	texture: Id_t,
}

Enemy :: struct {
	pos: [2]int,
	max_hp: int,
	hp: int,
	type: EnemyType
}

EnemySpawnDataItem :: struct {
	hp_scale: f32,
	pos: [2]int,
	type: EnemyType
};

EnemySpawnData :: struct {
	enemies: []EnemySpawnDataItem,
}

//CONSTS
enemy_data := [EnemyType]EnemyTypeData{
	.SmallGuy = {
		name = "A small guy",
		default_hp = 10,
		texture_size = {100, 100},
		texture = .SmallGuy
	},
	.BiggerGuy = {
		name = "A bigger guy",
		default_hp = 40,
		texture_size = {200, 200},
		texture = .BiggerGuy
	},
	.MaxEnemyType={
		name = "Missing No",
		default_hp = 10000000,
		texture_size = {400, 400},
		texture = .TextureMissing
	}
};

enemy_spawn_data :[]EnemySpawnData;
/*{
	{enemies={
		{type=.SmallGuy, pos={200, 300}},
	}},
	{enemies={
		{type=.SmallGuy, pos={100, 300}},
		{type=.SmallGuy, pos={300, 300}},
	}},
	{enemies={
		{type=.SmallGuy, pos={200, 300}, hp_scale=3.},
	}},
	{enemies={
		{type=.SmallGuy, pos={100, 300}},
		{type=.SmallGuy, pos={300, 300}},
		{type=.BiggerGuy, pos={150, 100}},
	}},
	{enemies={
		{type=.SmallGuy, pos={100, 100}},
		{type=.SmallGuy, pos={300, 300}, hp_scale=2.},
		{type=.BiggerGuy, pos={150, 500}},
	}},
}
*/

window_size :: [2]int{700, 700};
game_window_size :: [2]int{450, 700};
game_window_rect :: sdl.Rect{x=0, y=0, w=i32(game_window_size.x), h=i32(game_window_size.y)};

missing_texture_data := #load("images/texture-missing.jpg");
image_data := [Id_t][]u8{
	.TextureMissing = missing_texture_data,
	//UI
	.TheButton = #load("images/the-button.jpg"),
	.GameBG = #load("images/game-bg.jpg"),
	.TitleScreen = #load("images/title-screen.jpg"),
	.TitleScreenBlank = #load("images/title-screen-blank.jpg"),
	.StartButton = #load("images/start-button.jpg"),
	.ShowEnemiesButton = #load("images/show-enemies-button.jpg"),
	.PreviousEnemyButton = #load("images/previous-enemy-button.jpg"),
	.NextEnemyButton = #load("images/next-enemy-button.jpg"),
	.EnemySelection = #load("images/enemy-selection.jpg"),
	.CreateLevelButton = #load("images/create-level-button.jpg"),
	//Numbers
	.Number0 = #load("images/0.jpg"),
	.Number1 = #load("images/1.jpg"),
	.Number2 = #load("images/2.jpg"),
	.Number3 = #load("images/3.jpg"),
	.Number4 = #load("images/4.jpg"),
	.Number5 = #load("images/5.jpg"),
	.Number6 = #load("images/6.jpg"),
	.Number7 = #load("images/7.jpg"),
	.Number8 = #load("images/8.jpg"),
	.Number9 = #load("images/9.jpg"),
	//Enemies
	.SmallGuy = #load("images/small-guy.jpg"),
	.BiggerGuy = #load("images/bigger-guy.jpg"),
};

digit_ids := [10]Id_t{
	.Number0,
	.Number1,
	.Number2,
	.Number3,
	.Number4,
	.Number5,
	.Number6,
	.Number7,
	.Number8,
	.Number9,
};

milliseconds_per_frame :: 32;

the_button_rect :: sdl.Rect{x=i32(game_window_size.x+10), y=400, w=230, h=230}
start_button_rect :: sdl.Rect{x=i32(game_window_size.x+50), y=100, w=150, h=100};
show_enemies_button_rect :: sdl.Rect{x=i32(game_window_size.x+50), y=300, w=150, h=100};
create_level_button_rect :: sdl.Rect{x=i32(game_window_size.x+50), y=500, w=150, h=100};
previous_enemy_button_rect :: sdl.Rect{x=i32(game_window_size.x+25),y=i32(window_size.y - 200), w=75, h=75};
next_enemy_button_rect :: sdl.Rect{x=i32(window_size.x - 75 - 25),y=i32(window_size.y - 200), w=75, h=75};


//VARS
window : ^sdl.Window;
renderer : ^sdl.Renderer;
camera_pos : [2]f64

image_surfaces : [Id_t]^sdl.Surface;
images : [Id_t]^sdl.Texture;

game_state : GameState;
frame : uint;
score : uint;

show_enemy_type : EnemyType;

enemies : [dynamic]Enemy;

damage_stat : int;
selected_enemy : int;

current_wave : int;

current_enemy_page : int;

//UTILS
image_size :: proc(id: Id_t) -> (i32, i32) {
	w: i32;
	h: i32;
	sdl.QueryTexture(images[id], nil, nil, &w, &h);
	return w, h;
}

point_in_rect :: proc(point: [2]int, rect: sdl.Rect) -> bool {
	if point.x < int(rect.x) {
		return false;
	}
	if point.y < int(rect.y) {
		return false
	};
	if point.x > int(rect.x + rect.w) {
		return false;
	}
	if point.y > int(rect.y + rect.h) {
		return false;
	}
	return true;
}

rect_from_dimensions_and_point :: proc(dimensions: [2]int, point: [2]int) -> sdl.Rect {
	return sdl.Rect{x=i32(point.x), y=i32(point.y), w=i32(dimensions.x), h=i32(dimensions.y)};
}

//PROCS
init_images :: proc() -> bool {
	surface := sdl_image.Load_RW(sdl.RWFromMem(raw_data(missing_texture_data), i32(len(missing_texture_data))), true);
	if surface == nil {
		sdl.Log(sdl.GetError());
		return false;
	}
	image_surfaces[.TextureMissing] = surface;
	texture := sdl.CreateTextureFromSurface(renderer, surface); 
	sdl.FreeSurface(surface); // delete this line if surfaces are needed to be kept
	if texture == nil {
		sdl.Log(sdl.GetError());
		return false;
	}
	for id in Id_t {
		images[id] = texture;
	}

	for id in Id_t {
		surface := sdl_image.Load_RW(sdl.RWFromMem(raw_data(image_data[id]), i32(len(image_data[id]))), true);
		if surface == nil {
			return false;
		}
		color_key := sdl.MapRGB(surface.format, 0xFF, 0xFF, 0xFF);
		error := sdl.SetColorKey(surface, 1, color_key);
		if error != 0 {
			sdl.Log(sdl.GetError());
			return false;
		}

		image_surfaces[id] = surface;
		texture := sdl.CreateTextureFromSurface(renderer, surface); 
		sdl.FreeSurface(image_surfaces[id]); // delete this line if surfaces are needed to be kept
		if texture == nil {
			sdl.Log(sdl.GetError());
			return false;
		}
		images[id] = texture;
	}
	return true;
}

deinit_images :: proc() {
	for v in images {
		sdl.DestroyTexture(v);
	}
	for k, v in image_surfaces {
		//sdl.FreeSurface(v); uncomment this line if surfaces are needed to be kept
	}
}

init :: proc() -> bool {
	sdl.Init(sdl.INIT_EVERYTHING);
	window = sdl.CreateWindow(
		cstring("title"),
		sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED,
		i32(window_size.x), i32(window_size.y), {}
	);
	if window == nil {
		return false;
	}
	renderer = sdl.CreateRenderer(window, -1, {});
	if renderer == nil {
		return false;
	}

	if !init_images() {
		return false;
	}
	game_state = .TitleScreen;
	frame = 0;
	score = 0;

	enemies = make([dynamic]Enemy);

	damage_stat = 1;
	selected_enemy = 0;

	current_enemy_page = 0;

	current_wave = 0;
	return true;
}

deinit :: proc() -> bool{
	deinit_images();
	delete(enemies);
	sdl.DestroyRenderer(renderer);
	sdl.DestroyWindow(window);
	sdl.Quit();
	return true;
}

draw_number :: proc(num: uint, rect : sdl.Rect, n_digits: int) {
	digits := make([]u8, n_digits, context.temp_allocator);
	for i in 0..<len(digits) {
		digits[i] = 0;
	}
	num : uint = num;
	i := 0;
	for num > 0 {
		digits[i] = u8(num % 10);
		num /= 10;
		i += 1;
	}
	y := rect.y;
	digit_width := rect.w/i32(n_digits);
	x := rect.x + rect.w - digit_width;
	for i in 0..< n_digits {
		sdl.RenderCopy(renderer, images[digit_ids[digits[i]]], nil, &sdl.Rect{w=digit_width, h=rect.h, x=x, y=y});
		x -= digit_width;
	}
}

draw_game :: proc() {
	switch game_state {
	case .TitleScreen:
		rect := game_window_rect;
		if (frame % 32 < 24) {
			sdl.RenderCopy(renderer, images[.TitleScreen], nil, &rect);
		} else {
			sdl.RenderCopy(renderer, images[.TitleScreenBlank], nil, &rect);
		}
	case .Game:
		rect := game_window_rect;
		sdl.RenderCopy(renderer, images[.GameBG], nil, &rect);
		for enemy, i in enemies {
			pos := enemy.pos;
			size := enemy_data[enemy.type].texture_size;
			rect := rect_from_dimensions_and_point(size, pos);
			sdl.RenderCopy(renderer, images[enemy_data[enemy.type].texture], nil, &rect);

			max_hp_rect := sdl.Rect{x=rect.x, y=rect.y - 10 - 10, w=rect.w, h=10};
			hp_rect := sdl.Rect{x=max_hp_rect.x, y=max_hp_rect.y, h=max_hp_rect.h, w=i32(f32(max_hp_rect.w)*f32(enemy.hp)/f32(enemy.max_hp))};
			sdl.SetRenderDrawColor(renderer, 0xDF, 0x10, 0x10, 0xFF);
			sdl.RenderFillRect(renderer, &max_hp_rect);
			sdl.SetRenderDrawColor(renderer, 0x10, 0xAf, 0x10, 0xFF);
			sdl.RenderFillRect(renderer, &hp_rect);
			sdl.SetRenderDrawColor(renderer, 0x10, 0x10, 0x10, 0xFF);
			sdl.RenderDrawRect(renderer, &max_hp_rect);

			if i == selected_enemy {
				enemy_midpoint := i32(size.x/2 + pos.x);
				selection_rect := sdl.Rect{w=50, h=50, x=enemy_midpoint - 25, y=rect.y + i32(size.y)};
				sdl.RenderCopy(renderer, images[.EnemySelection], nil, &selection_rect);
			}
		}
	case .ShowEnemies:
		rect := game_window_rect;
		sdl.RenderCopy(renderer, images[.GameBG], nil, &rect);

		enemy_size := enemy_data[show_enemy_type].texture_size;
		pos := game_window_size/2 - enemy_size/2;
		rect = rect_from_dimensions_and_point(enemy_size, pos);
		sdl.RenderCopy(renderer, images[enemy_data[show_enemy_type].texture], nil,  &rect);
	case .CreateLevel:
		rect := game_window_rect;
		sdl.RenderCopy(renderer, images[.GameBG], nil, &rect);
	}
}

enemy_page_width :: 3;
enemy_page_height :: 5;
n_enemies_per_page :: enemy_page_width*enemy_page_height;

get_number_of_enemy_pages :: proc() -> int {
	n_enemies := int(EnemyType.MaxEnemyType);
	if n_enemies % n_enemies_per_page == 0 {
		return n_enemies/n_enemies_per_page;
	} else {
		return n_enemies/n_enemies_per_page + 1;
	}
}

get_enemies_page :: proc(page_n : int) -> (enemies_page: [n_enemies_per_page]EnemyType) {
	first_enemy_n := page_n*n_enemies_per_page;
	for i in 0..< n_enemies_per_page {
		enemy_n := i+first_enemy_n;
		if  enemy_n >= int(EnemyType.MaxEnemyType) {
			enemies_page[i] = EnemyType.MaxEnemyType;
			continue;
		}
		enemy := EnemyType(enemy_n);
		enemies_page[i] = enemy;
	}
	return;
}

draw_toolbar :: proc() {
	toolbar_rect := sdl.Rect{x=i32(game_window_size.x), y=0, w=i32(window_size.x-game_window_size.x), h=i32(window_size.y)};
	sdl.SetRenderDrawColor(renderer, 0xA0, 0x60, 0xA0, 0xFF);
	sdl.RenderFillRect(renderer, &toolbar_rect);

	switch game_state {
	case .TitleScreen:
		rect := start_button_rect;
		sdl.RenderCopy(renderer, images[.StartButton], nil, &rect);
		rect = show_enemies_button_rect;
		sdl.RenderCopy(renderer, images[.ShowEnemiesButton], nil, &rect);
		rect = create_level_button_rect;
		sdl.RenderCopy(renderer, images[.CreateLevelButton], nil, &rect);
	case .Game:
		draw_number(score, sdl.Rect{w=240, h=40, x=i32(game_window_size.x), y=50}, 6);
		rect := the_button_rect;
		sdl.RenderCopy(renderer, images[.TheButton], nil, &rect);
	case .ShowEnemies:
		rect := previous_enemy_button_rect;
		sdl.RenderCopy(renderer, images[.PreviousEnemyButton], nil, &rect);
		rect = next_enemy_button_rect;
		sdl.RenderCopy(renderer, images[.NextEnemyButton], nil, &rect);
		draw_number(uint(show_enemy_type), sdl.Rect{w=40*3, h=40, x=previous_enemy_button_rect.x+40, y=next_enemy_button_rect.y+next_enemy_button_rect.h+10}, 3);
	case .CreateLevel:
		rect := previous_enemy_button_rect;
		sdl.RenderCopy(renderer, images[.PreviousEnemyButton], nil, &rect);
		rect = next_enemy_button_rect;
		sdl.RenderCopy(renderer, images[.NextEnemyButton], nil, &rect);
		n_enemy_pages := get_number_of_enemy_pages();
		draw_number(uint(current_enemy_page), sdl.Rect{w=40*3, h=40, x=previous_enemy_button_rect.x+40, y=next_enemy_button_rect.y+next_enemy_button_rect.h+10}, 3);

		//Draw enemy types
		enemy_page_type_array := get_enemies_page(current_enemy_page);
		enemy_background_rects : [n_enemies_per_page]sdl.Rect;
		enemy_background_rect_size : i32 = 70;
		enemy_background_rect_padding : i32 = 10;
		enemy_background_rect := sdl.Rect{y=100, w=enemy_background_rect_size, h=enemy_background_rect_size};
		for y in 0..<enemy_page_height {
			enemy_background_rect.x = toolbar_rect.x+enemy_background_rect_padding;
			for x in 0..<enemy_page_width {
				enemy_background_rects[x + y*enemy_page_width] = enemy_background_rect;

				enemy_background_rect.x += enemy_background_rect_size;
				enemy_background_rect.x += enemy_background_rect_padding;
			}
			enemy_background_rect.y += enemy_background_rect_size;
			enemy_background_rect.y += enemy_background_rect_padding;
		}

		sdl.SetRenderDrawColor(renderer, 0xAA, 0xAA, 0xAA, 0xFF);
		sdl.RenderFillRects(renderer, raw_data(&enemy_background_rects), len(enemy_background_rects));

		enemy_rect_size : i32 = 70;
		enemy_rect_padding : i32 = 10;
		enemy_rect := sdl.Rect{y=100, w=enemy_rect_size, h=enemy_rect_size};

		for y in 0..<enemy_page_height {
			enemy_rect.x = toolbar_rect.x+enemy_rect_padding;
			for x in 0..<enemy_page_width {
				enemy_type := enemy_page_type_array[x + y*enemy_page_width];
				if enemy_type != .MaxEnemyType {
					sdl.RenderCopy(renderer, images[enemy_data[enemy_type].texture], nil, &enemy_rect);
				}

				enemy_rect.x += enemy_rect_size;
				enemy_rect.x += enemy_rect_padding;
			}
			enemy_rect.y += enemy_rect_size;
			enemy_rect.y += enemy_rect_padding;
		}
	}
}

draw :: proc() {
	sdl.SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
	sdl.RenderFillRect(renderer, nil);
	draw_game();
	draw_toolbar();
	sdl.RenderPresent(renderer);
}

spawn_enemy :: proc(enemy_type: EnemyType, pos : [2]int, hp_scale: f32 = 1.) {
	append(&enemies, Enemy{type=enemy_type, max_hp=int(f32(enemy_data[enemy_type].default_hp)*hp_scale), hp=int(f32(enemy_data[enemy_type].default_hp)*hp_scale), pos=pos});
}

spawn_wave :: proc(wave: int) {
	wave := wave;
	if wave >= len(enemy_spawn_data) {
		wave %= len(enemy_spawn_data); // TEMP temp
	}
	data := enemy_spawn_data[wave];
	for spawn in data.enemies {
		hp_scale := spawn.hp_scale;
		if hp_scale == 0. {
			hp_scale = 1.;
		}
		spawn_enemy(spawn.type, spawn.pos, hp_scale=hp_scale);
	}
}

get_enemy_rect :: proc(enemy: Enemy) -> (enemy_rect: sdl.Rect) {
	enemy_rect.x = i32(enemy.pos.x);
	enemy_rect.y = i32(enemy.pos.y);
	enemy_rect.w = i32(enemy_data[enemy.type].texture_size.x);
	enemy_rect.h = i32(enemy_data[enemy.type].texture_size.y);
	return;
}

do_damage_to_selected_enemy :: proc(damage: int) {
	if selected_enemy >= len(enemies) {
		selected_enemy = 0;
		return;
	}
	enemies[selected_enemy].hp -= damage;
	if enemies[selected_enemy].hp <= 0 {
		enemies[selected_enemy].hp = 0;
		unordered_remove(&enemies, selected_enemy);
		if selected_enemy <= len(enemies) {
			selected_enemy = 0;
		}
	}

	if len(enemies) <= 0 {
		current_wave += 1;
		spawn_wave(current_wave);
	}
}

do_buttons :: proc(mouse_pos: [2]int) {
	switch game_state {
	case .TitleScreen:
		if point_in_rect(mouse_pos, start_button_rect) {
			game_state = .Game;
			spawn_wave(current_wave);
		}
		if point_in_rect(mouse_pos, show_enemies_button_rect) {
			game_state = .ShowEnemies;
			show_enemy_type = EnemyType(0);
		}
		if point_in_rect(mouse_pos, create_level_button_rect) {
			game_state = .CreateLevel;
			current_enemy_page = 0;
		}
	case .Game:
		if point_in_rect(mouse_pos, the_button_rect) {
			do_damage_to_selected_enemy(damage_stat);
		}
		for enemy, i in enemies {
			if point_in_rect(mouse_pos, get_enemy_rect(enemy)) {
				selected_enemy = i;
			}
		}
	case .ShowEnemies:
		if point_in_rect(mouse_pos, previous_enemy_button_rect) {
			show_enemy_type = EnemyType((int(show_enemy_type) - 1)%%int(EnemyType.MaxEnemyType));
		}
		if point_in_rect(mouse_pos, next_enemy_button_rect) {
			show_enemy_type = EnemyType((int(show_enemy_type) + 1)%%int(EnemyType.MaxEnemyType));
		}
	case .CreateLevel:

	}
}

mainloop :: proc() {
	for {
		e : sdl.Event;
		for sdl.PollEvent(&e) {
			#partial switch e.type {
			case .QUIT:
				return;
			case .MOUSEBUTTONDOWN:
				x := e.button.x;
				y := e.button.y;
				do_buttons([2]int{int(x), int(y)})
			}
		}

		draw();
		sdl.Delay(milliseconds_per_frame);
		frame += 1;
		free_all(context.temp_allocator);
	}
}

main :: proc() {
	if !init() {
		sdl.LogError(0, cstring("Failed to init!\n"));
		return;
	}

	//write_spawn_data("temp.txt", enemy_spawn_data);
	spawn_data := load_spawn_data("temp.txt");
	enemy_spawn_data = spawn_data;

	mainloop();

	if !deinit() {
		sdl.LogError(0, cstring("Failed while exiting!\n"));
		return;
	}
}


