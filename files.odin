package main
import sdl "vendor:sdl2"
import "core:strings"
import "core:strconv"
import "core:os"


//EnemySpawnDataItem :: struct {
//	hp_scale: f32,
//	pos: [2]int,
//	type: EnemyType
//};
//
//EnemySpawnData :: struct {
//	enemies: []EnemySpawnDataItem,
//}

write_spawn_data :: proc(filename: string, spawn_data: []EnemySpawnData) {
	sb := strings.builder_make();
	strings.write_string(&sb, "Version-Barsik\n");
	for spawn_data_item in spawn_data {
		strings.write_string(&sb, "Wave\n");
		for spawn in spawn_data_item.enemies {
			strings.write_string(&sb, "Spawn\n");
			strings.write_string(&sb, "Type\n");
			strings.write_int(&sb, int(spawn.type));
			strings.write_string(&sb, "\n");
			strings.write_string(&sb, "HP-scale\n");
			strings.write_f32(&sb, spawn.hp_scale, 'f');
			strings.write_string(&sb, "\n");
			strings.write_string(&sb, "Pos-x\n");
			strings.write_int(&sb, spawn.pos.x);
			strings.write_string(&sb, "\n");
			strings.write_string(&sb, "Pos-y\n");
			strings.write_int(&sb, spawn.pos.y);
			strings.write_string(&sb, "\n");
		}
		strings.write_string(&sb, "End-Wave\n");
	}
	strings.write_string(&sb, "END.");
	if !os.write_entire_file(filename, transmute([]u8) strings.to_string(sb)) {
		sdl.Log("Error! when writing spawn data\n");
	};
}

load_spawn_data :: proc(filename: string) -> []EnemySpawnData {
	_file, _ok := os.read_entire_file_from_filename(filename);
	if !_ok {
		sdl.Log("Error! when reading spawn data\n");
		return nil;
	}
	file := transmute(string) _file;
	waves := make([dynamic][dynamic]EnemySpawnDataItem, allocator = context.temp_allocator);
	line, ok := strings.fields_iterator(&file);
	if line != "Version-Barsik" {
		sdl.Log("Error! while reading spawn file. Wrong version, expected Version Barsik\n");
		return nil;
	}
	for file != "" {
		line, ok = strings.fields_iterator(&file);
		if line == "END." {
			break;
		}
		if !ok {break;}
		if line != "Wave" {
			sdl.Log("Error! while reading spawn file. Expected 'Wave'\n");
			return nil;
		}
		wave := make([dynamic]EnemySpawnDataItem, allocator=context.temp_allocator);
		for line != "End-Wave" {
			line, ok = strings.fields_iterator(&file);
			if !ok {sdl.Log("Error! unexpected EOF while reading spawn data"); return nil;}
			if line == "End-Wave" {
				break;
			}
			if line != "Spawn" {
				sdl.Log("Error! while reading spawn file. Expected 'Spawn'\n");
				return nil;
			}

			line, ok = strings.fields_iterator(&file);
			if !ok {sdl.Log("Error! unexpected EOF while reading spawn data"); return nil;}
			if line != "Type" {
				sdl.Log("Error! while reading spawn file. Expected 'Spawn'\n");
				return nil;
			}

			line, ok = strings.fields_iterator(&file);
			if !ok {sdl.Log("Error! unexpected EOF while reading spawn data"); return nil;}
			type, ok := strconv.parse_int(line);
			if !ok {sdl.Log("Error! while reading spawn data expected an integer"); return nil;}

			line, ok = strings.fields_iterator(&file);
			if !ok {sdl.Log("Error! unexpected EOF while reading spawn data"); return nil;}
			if line != "HP-scale" {
				sdl.Log("Error! while reading spawn file. Expected 'HP-scale'\n");
				return nil;
			}

			line, ok = strings.fields_iterator(&file);
			if !ok {sdl.Log("Error! unexpected EOF while reading spawn data"); return nil;}
			hp_scale, ok2 := strconv.parse_f32(line);
			if !ok2 {sdl.Log("Error! while reading spawn data expected a float"); return nil;}

			line, ok = strings.fields_iterator(&file);
			if !ok {sdl.Log("Error! unexpected EOF while reading spawn data"); return nil;}
			if line != "Pos-x" {
				sdl.Log("Error! while reading spawn file. Expected 'Pos-x'\n");
				return nil;
			}

			line, ok = strings.fields_iterator(&file);
			if !ok {sdl.Log("Error! unexpected EOF while reading spawn data"); return nil;}
			pos_x, ok3 := strconv.parse_int(line);
			if !ok3 {sdl.Log("Error! while reading spawn data expected an integer"); return nil;}

			line, ok = strings.fields_iterator(&file);
			if !ok {sdl.Log("Error! unexpected EOF while reading spawn data"); return nil;}
			if line != "Pos-y" {
				sdl.Log("Error! while reading spawn file. Expected 'Pos-y'\n");
				return nil;
			}

			line, ok = strings.fields_iterator(&file);
			if !ok {sdl.Log("Error! unexpected EOF while reading spawn data"); return nil;}
			pos_y, ok4 := strconv.parse_int(line);
			if !ok4 {sdl.Log("Error! while reading spawn data expected an integer"); return nil;}

			spawn : EnemySpawnDataItem = {type=EnemyType(type), hp_scale=hp_scale, pos={pos_x, pos_y}};
			append(&wave, spawn);

		}
		append(&waves, wave);
	}
	res := make([]EnemySpawnData, len(waves));
	for wave, i in waves {
		res[i] = {enemies=make([]EnemySpawnDataItem, len(wave))}
		for spawn, j in wave {
			res[i].enemies[j] = spawn;
		}
	}
	return res;
}
