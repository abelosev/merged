/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   get_map.c                                          :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: vfekete <marvin@42.fr>                     +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/07/03 13:27:09 by burei             #+#    #+#             */
/*   Updated: 2026/08/16                              ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "cub3d.h"

static void	init_empty_texts(t_map *map)
{
	map->floor_color[0] = -1;
	map->floor_color[1] = -1;
	map->floor_color[2] = -1;
	map->ceiling_color[0] = -1;
	map->ceiling_color[1] = -1;
	map->ceiling_color[2] = -1;
	map->ceiling_found = false;
	map->floor_found = false;
	map->north_tex.tex_path = NULL;
	map->south_tex.tex_path = NULL;
	map->east_tex.tex_path = NULL;
	map->west_tex.tex_path = NULL;
	map->north_tex.img_ptr = NULL;
	map->south_tex.img_ptr = NULL;
	map->east_tex.img_ptr = NULL;
	map->west_tex.img_ptr = NULL;
	map->north_tex.tex_found = false;
	map->south_tex.tex_found = false;
	map->east_tex.tex_found = false;
	map->west_tex.tex_found = false;
	map->north_tex.tex_loaded = false;
	map->south_tex.tex_loaded = false;
	map->east_tex.tex_loaded = false;
	map->west_tex.tex_loaded = false;
	map->curr_tex = NULL;
}

static void	init_empty_map(t_map *map)
{
	map->parse_error = NO_ERROR;
	map->error_msg = "";
	map->position.x = 0;
	map->position.y = 0;
	map->direction.x = 0;
	map->direction.y = 0;
	map->plane.x = 0;
	map->plane.y = 0;
	map->deg_angle = 0;
	map->height = 0;
	map->widths = NULL;
	map->cells = NULL;
	map->row_capacity = 0;
	init_empty_texts(map);
}

static int	count_lines(char **lines)
{
	int	total;

	total = 0;
	while (lines[total])
		total++;
	return (total);
}

static int	find_map_start(t_map *map, char **lines)
{
	int	i;

	i = 0;
	while (lines[i])
	{
		if (is_blank_line(lines[i]))
			i++;
		else if (try_parse_config(map, lines[i]))
		{
			if (map->parse_error != NO_ERROR)
				return (-1);
			i++;
		}
		else
			break ;
	}
	check_config_complete(map);
	if (map->parse_error != NO_ERROR)
		return (-1);
	if (!lines[i])
	{
		map->parse_error = INVALID_CHAR;
		return (-1);
	}
	return (i);
}

static void	parse_map_file(char *map_path, t_map *map)
{
	int		fd;
	int		map_start;
	int		total;
	t_list	*lst;
	char	**lines;

	fd = open(map_path, O_RDONLY);
	if (fd == -1)
	{
		map->parse_error = OPEN_FAIL;
		return ;
	}
	lst = read_lines(fd, map);
	close(fd);
	if (map->parse_error != NO_ERROR)
		return ;
	lines = list_to_array(lst, map);
	if (!lines)
		return ;
	total = count_lines(lines);
	map_start = find_map_start(map, lines);
	if (map_start >= 0)
		build_map(map, lines, map_start, total);
	free_lines(lines);
}

t_map	*get_map(char *map_path)
{
	t_map	*map;

	map = malloc(sizeof(t_map));
	if (!map)
	{
		ft_putstr_fd("Error\nMalloc error\n", 2);
		exit(EXIT_FAILURE);
	}
	init_empty_map(map);
	parse_map_file(map_path, map);
	if (map->parse_error != NO_ERROR)
		return (map);
	validate_map_closed(map);
	return (map);
}