#include "../../../includes/cub3d.h"

static int	is_allowed_char(char c)
{
	return (c == '0' || c == '1' || c == ' '
		|| c == 'N' || c == 'S' || c == 'E' || c == 'W');
}

static int	is_player_char(char c)
{
	return (c == 'N' || c == 'S' || c == 'E' || c == 'W');
}

static int	validate_map_line(t_map *map, char *line, int *player_count)
{
	int	x;

	x = 0;
	while (line[x])
	{
		if (!is_allowed_char(line[x]))
		{
			map->parse_error = INVALID_CHAR;
			return (0);
		}
		if (is_player_char(line[x]))
			(*player_count)++;
		x++;
	}
	return (1);
}

static int	allocate_map(t_map *map, int height)
{
	map->height = height;
	map->widths = ft_calloc(height, sizeof(int));
	map->cells = ft_calloc(height + 1, sizeof(int *));
	if (!map->widths || !map->cells)
	{
		map->parse_error = MALLOC_ERROR;
		return (0);
	}
	return (1);
}

static int	fill_map_line(t_map *map, char *line, int y)
{
	int	x;

	map->widths[y] = ft_strlen(line);
	map->cells[y] = malloc(sizeof(int) * map->widths[y]);
	if (!map->cells[y])
	{
		map->parse_error = MALLOC_ERROR;
		return (0);
	}
	x = 0;
	while (line[x])
	{
		if (line[x] == '0')
			map->cells[y][x] = 0;
		else if (line[x] == '1')
			map->cells[y][x] = 1;
		else if (line[x] == ' ')
			map->cells[y][x] = -1;
		else
		{
			init_player(y, x, line[x], map);
			map->cells[y][x] = 0;
		}
		x++;
	}
	return (1);
}

void	build_map(t_map *map, char **lines, int start, int total)
{
	int	y;
	int	player_count;
	int	height;

	height = total - start;
	if (height <= 0)
	{
		map->parse_error = INVALID_CHAR;
		return ;
	}
	player_count = 0;
	y = 0;
	while (y < height)
	{
		if (is_blank_line(lines[start + y]))
		{
			map->parse_error = MAP_SPLIT;
			return ;
		}
		if (!validate_map_line(map, lines[start + y], &player_count))
			return ;
		y++;
	}
	if (player_count == 0)
	{
		map->parse_error = NO_PLAYER;
		return ;
	}
	if (player_count > 1)
	{
		map->parse_error = DOUBLE_PLAYER;
		return ;
	}
	if (!allocate_map(map, height))
		return ;
	y = 0;
	while (y < height)
	{
		if (!fill_map_line(map, lines[start + y], y))
			return ;
		y++;
	}
}