/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   get_map.c                                          :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: vfekete <marvin@42.fr>                     +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/07/03 13:27:09 by burei             #+#    #+#             */
/*   Updated: 2026/08/05 17:00:16 by vfekete          ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "../../../includes/cub3d.h"

void	init_empty_texts(t_map *map)
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

void	init_empty_map(t_map *map)
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
	init_empty_texts(map);
}

void	parse_map(char *map_path, t_map *map)
{
	int	map_fd;

	map_fd = open(map_path, O_RDONLY);
	if (map_fd == -1)
	{
		if (map->parse_error == NO_ERROR)
			map->parse_error = OPEN_FAIL;
		return ;
	}
	parse_assets(map_fd, map);
	if (!found_all_assets(map))
	{
		if (map->parse_error == NO_ERROR)
			map->parse_error = MISSING_ASSETS;
		close(map_fd);
		return ;
	}
	load_map_data(map_fd, map);
	close(map_fd);
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
	parse_map(map_path, map);
	if (map->parse_error != NO_ERROR)
		return (map);
	validate_floodfill(map);
	return (map);
}
