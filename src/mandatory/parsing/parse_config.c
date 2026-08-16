#include "cub3d.h"

static int	match_identifier(char *line, char *id)
{
	size_t	len;

	len = ft_strlen(id);
	if (ft_strncmp(line, id, len) != 0)
		return (0);
	return (line[len] == '\0' || is_space_char(line[len]));
}

static t_texture	*get_texture(t_map *map, char *id)
{
	if (!ft_strncmp(id, "NO", 3))
		return (&map->north_tex);
	if (!ft_strncmp(id, "SO", 3))
		return (&map->south_tex);
	if (!ft_strncmp(id, "WE", 3))
		return (&map->west_tex);
	return (&map->east_tex);
}

static void	set_texture(t_map *map, char *id, char *rest)
{
	t_texture	*texture;
	char		*path;
	char		*end;

	texture = get_texture(map, id);
	if (texture->tex_path)
	{
		map->parse_error = DOUBLE_TEXTURES;
		return ;
	}
	path = skip_spaces(rest);
	if (!*path)
	{
		map->parse_error = INVALID_TEXTURES;
		return ;
	}
	end = path;
	while (*end && !is_space_char(*end))
		end++;
	if (*end)
	{
		*end = '\0';
		if (*skip_spaces(end + 1))
		{
			map->parse_error = INVALID_TEXTURES;
			return ;
		}
	}
	texture->tex_path = ft_strdup(path);
	if (!texture->tex_path)
	{
		map->parse_error = MALLOC_ERROR;
		return ;
	}
	texture->tex_found = true;
}

static int	count_commas(char *str)
{
	int	count;

	count = 0;
	while (*str)
	{
		if (*str == ',')
			count++;
		str++;
	}
	return (count);
}

static int	parse_rgb_token(char *token, int *out)
{
	char	*start;
	char	*end;

	start = skip_spaces(token);
	end = start + ft_strlen(start);
	while (end > start && is_space_char(end[-1]))
		end--;
	*end = '\0';
	return (parse_int_strict(start, out));
}

static int	extract_rgb(char *rest, int values[3])
{
	char	**tokens;
	int		i;

	if (count_commas(rest) != 2)
		return (0);
	tokens = ft_split(rest, ',');
	if (!tokens)
		return (-1);
	i = 0;
	while (tokens[i])
		i++;
	if (i != 3
		|| !parse_rgb_token(tokens[0], &values[0])
		|| !parse_rgb_token(tokens[1], &values[1])
		|| !parse_rgb_token(tokens[2], &values[2]))
	{
		ft_free_split(tokens);
		return (0);
	}
	ft_free_split(tokens);
	return (1);
}

static void	parse_color(t_map *map, int *color, bool *found, char *rest)
{
	int	values[3];
	int	result;

	if (*found)
	{
		map->parse_error = DOUBLE_RGB;
		return ;
	}
	result = extract_rgb(skip_spaces(rest), values);
	if (result == -1)
	{
		map->parse_error = MALLOC_ERROR;
		return ;
	}
	if (result == 0)
	{
		map->parse_error = WRONG_RGB;
		return ;
	}
	color[0] = values[0];
	color[1] = values[1];
	color[2] = values[2];
	*found = true;
}

int	try_parse_config(t_map *map, char *line)
{
	if (match_identifier(line, "NO"))
		set_texture(map, "NO", line + 2);
	else if (match_identifier(line, "SO"))
		set_texture(map, "SO", line + 2);
	else if (match_identifier(line, "WE"))
		set_texture(map, "WE", line + 2);
	else if (match_identifier(line, "EA"))
		set_texture(map, "EA", line + 2);
	else if (match_identifier(line, "F"))
		parse_color(map, map->floor_color, &map->floor_found, line + 1);
	else if (match_identifier(line, "C"))
		parse_color(map, map->ceiling_color, &map->ceiling_found, line + 1);
	else
		return (0);
	return (1);
}

void	check_config_complete(t_map *map)
{
	if (map->parse_error != NO_ERROR)
		return ;
	if (!map->north_tex.tex_path || !map->south_tex.tex_path
		|| !map->west_tex.tex_path || !map->east_tex.tex_path
		|| !map->floor_found || !map->ceiling_found)
		map->parse_error = MISSING_ASSETS;
}