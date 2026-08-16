#ifndef PARSING_H
# define PARSING_H

# include "../libft/libft.h"
# include "../src/gnl/get_next_line.h"
# include <stdbool.h>
# include <stddef.h>

/* PARSING ERRORS */

typedef enum e_parse_errors
{
	NO_ERROR,
	NO_PLAYER,
	DOUBLE_PLAYER,
	INVALID_CHAR,
	INVALID_TEXTURES,
	DOUBLE_TEXTURES,
	MAP_SPLIT,
	WRONG_RGB,
	DOUBLE_RGB,
	MISSING_ASSETS,
	UNEXPECTED_ASSETS,
	OPEN_FAIL,
	TEXTURE_LOAD_FAIL,
	MAP_NOT_CLOSE_FAIL,
	INVALID_WHITESPACE,
	MALLOC_ERROR
}					t_parse_errors;

/* SHARED MAP STRUCTURES */

typedef struct s_point
{
	double			x;
	double			y;
}					t_point;

typedef struct s_point_int
{
	int				x;
	int				y;
}					t_point_int;

typedef struct s_lode_raycast
{
	double			ray_x;
	double			ray_y;
	double			sidedist_x;
	double			sidedist_y;
	double			delta_dist_x;
	double			delta_dist_y;
	int				map_x;
	int				map_y;
	int				step_x;
	int				step_y;
	int				side;
	int				line_height;
	double			wall_x;
	int				d;
}					t_lode_raycast;

typedef struct s_texture
{
	void			*img_ptr;
	char			*data;
	int				width;
	int				height;
	int				bpp;
	int				line_len;
	int				endian;
	char			*tex_path;
	bool			tex_found;
	bool			tex_loaded;
}					t_texture;

typedef struct s_map
{
	int				floor_color[3];
	int				ceiling_color[3];
	bool			floor_found;
	bool			ceiling_found;
	bool			map_ended;
	unsigned int	parse_error;
	char			*error_msg;
	t_point			position;
	t_point			direction;
	t_point			plane;
	float			deg_angle;
	int				**cells;
	int				*widths;
	int				height;
	int				row_capacity;
	t_lode_raycast	lode;
	t_texture		north_tex;
	t_texture		south_tex;
	t_texture		east_tex;
	t_texture		west_tex;
	t_texture		*curr_tex;
}					t_map;

/* GET MAP */

t_map				*get_map(char *map_path);

/* PARSE FILE */

t_list				*read_lines(int fd, t_map *map);
char				**list_to_array(t_list *lst, t_map *map);
void				free_lines(char **lines);

/* PARSE CONFIG */

int					try_parse_config(t_map *map, char *line);
void				check_config_complete(t_map *map);

/* PARSE MAP */

void				build_map(t_map *map, char **lines, int start, int total);

/* MAP VALIDATION */

void				validate_floodfill(t_map *map);

/* PARSE UTILS */

int					is_space_char(char c);
char				*skip_spaces(char *s);
int					parse_int_strict(char *s, int *out);
int					is_blank_line(char *line);
void				strip_newline(char *line);

/* PARSER DEPENDENCIES */

void				init_player(int y, int x, char direction, t_map *map);
void				ft_free_split(char **split);

#endif