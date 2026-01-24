package main
import sdl "vendor:sdl2"
import sdl_image "vendor:sdl2/image"

//TYPES 
GameState :: enum {
	TitleScreen,
	Game,
	ShowEnemies,
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
	.MaxEnemyType={}
};

//CONSTS
window_size :: [2]int{700, 700};
game_window_size :: [2]int{450, 700};
game_window_rect :: sdl.Rect{x=0, y=0, w=i32(game_window_size.x), h=i32(game_window_size.y)};

missing_texture_data := #load("images/texture-missing.jpg");
image_data := []ImageData{
	{id=.TextureMissing, data=missing_texture_data},
	{id=.TheButton, data=#load("images/the-button.jpg")},
	{id=.GameBG, data=#load("images/game-bg.jpg")},
	{id=.TitleScreen, data=#load("images/title-screen.jpg")},
	{id=.TitleScreenBlank, data=#load("images/title-screen-blank.jpg")},
	{id=.StartButton, data=#load("images/start-button.jpg")},
	{id=.ShowEnemiesButton, data=#load("images/show-enemies-button.jpg")},
	{id=.PreviousEnemyButton, data=#load("images/previous-enemy-button.jpg")},
	{id=.NextEnemyButton, data=#load("images/next-enemy-button.jpg")},
	{id=.Number0, data=#load("images/0.jpg")},
	{id=.Number1, data=#load("images/1.jpg")},
	{id=.Number2, data=#load("images/2.jpg")},
	{id=.Number3, data=#load("images/3.jpg")},
	{id=.Number4, data=#load("images/4.jpg")},
	{id=.Number5, data=#load("images/5.jpg")},
	{id=.Number6, data=#load("images/6.jpg")},
	{id=.Number7, data=#load("images/7.jpg")},
	{id=.Number8, data=#load("images/8.jpg")},
	{id=.Number9, data=#load("images/9.jpg")},
	{id=.SmallGuy, data=#load("images/small-guy.jpg")},
	{id=.BiggerGuy, data=#load("images/bigger-guy.jpg")},
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
show_enemies_button_rect :: sdl.Rect{x=i32(game_window_size.x+50), y=400, w=150, h=100};
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

	for data in image_data {
		surface := sdl_image.Load_RW(sdl.RWFromMem(raw_data(data.data), i32(len(data.data))), true);
		if surface == nil {
			return false;
		}
		color_key := sdl.MapRGB(surface.format, 0xFF, 0xFF, 0xFF);
		error := sdl.SetColorKey(surface, 1, color_key);
		if error != 0 {
			sdl.Log(sdl.GetError());
			return false;
		}

		image_surfaces[data.id] = surface;
		texture := sdl.CreateTextureFromSurface(renderer, surface); 
		sdl.FreeSurface(image_surfaces[data.id]); // delete this line if surfaces are needed to be kept
		if texture == nil {
			sdl.Log(sdl.GetError());
			return false;
		}
		images[data.id] = texture;
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
	append(&enemies, Enemy{type=.SmallGuy, max_hp=enemy_data[.SmallGuy].default_hp, hp=enemy_data[.SmallGuy].default_hp, pos=[2]int{100, 100}});

	damage_stat = 1;
	selected_enemy = 0;
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
		for enemy in enemies {
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
		}
	case .ShowEnemies:
		rect := game_window_rect;
		sdl.RenderCopy(renderer, images[.GameBG], nil, &rect);

		enemy_size := enemy_data[show_enemy_type].texture_size;
		pos := game_window_size/2 - enemy_size/2;
		rect = rect_from_dimensions_and_point(enemy_size, pos);
		sdl.RenderCopy(renderer, images[enemy_data[show_enemy_type].texture], nil,  &rect);
	}
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
	}
}

draw :: proc() {
	sdl.SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
	sdl.RenderFillRect(renderer, nil);
	draw_game();
	draw_toolbar();
	sdl.RenderPresent(renderer);
}

do_buttons :: proc(mouse_pos: [2]int) {
	switch game_state {
	case .TitleScreen:
		if point_in_rect(mouse_pos, start_button_rect) {
			game_state = .Game;
		}
		if point_in_rect(mouse_pos, show_enemies_button_rect) {
			game_state = .ShowEnemies;
			show_enemy_type = EnemyType(0);
		}
	case .Game:
		if point_in_rect(mouse_pos, the_button_rect) {
			enemies[selected_enemy].hp -= damage_stat;
			if enemies[selected_enemy].hp < 0 {
				enemies[selected_enemy].hp = 0;
			}
			sdl.Log("hp = %d\n", enemies[selected_enemy].hp);
		}
	case .ShowEnemies:
		if point_in_rect(mouse_pos, previous_enemy_button_rect) {
			show_enemy_type = EnemyType((int(show_enemy_type) - 1)%%int(EnemyType.MaxEnemyType));
		}
		if point_in_rect(mouse_pos, next_enemy_button_rect) {
			show_enemy_type = EnemyType((int(show_enemy_type) + 1)%%int(EnemyType.MaxEnemyType));
		}
	}
}

mainloop :: proc() {
	for true {
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

	mainloop();

	if !deinit() {
		sdl.LogError(0, cstring("Failed while exiting!\n"));
		return;
	}
}


