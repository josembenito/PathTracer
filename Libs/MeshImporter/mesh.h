#pragma once

#include <vector>
#include <string>
#include "node.h"
#include "maths_funcs.h"

#ifdef USE_OPENGL
#include <GL/Glew.h>
#endif

struct Meshgroup {

	// geometry

	// shader 
	struct Texture {
		unsigned char* image_data = nullptr;
		int x = 0, y = 0, n = 0;
	};

	struct Mesh {

//        const char name[128];
		float *vp; // array of vertex points
        float *vn; // array of vertex normals
        float *vc; // array of vertex colors
        float *vtans;
		std::vector<float *> uvs;
		unsigned *faces_indices;
        
        int vertex_count;
        int face_count;
        int index_count;
        unsigned int MaterialIndex;

		Texture diffuse;
		Texture normal;
        Texture emissive;

        vec3 diffuse_base_color;
        
#ifdef USE_OPENGL
		GLuint vao;
		GLuint points_vbo;
		GLuint normals_vbo;
		std::vector<GLuint> uvs_vbos;
		GLuint tangents_vbo;
		GLuint faces_vbo;
		GLuint nmap_tex;
		GLuint dmap_tex;
        
        int model_matrix_location;
        int normal_map_location;
        int diffuse_map_location;
        int diffuse_base_color_location;
        int ambient_color_location;

        
        void load_geometry_to_gpu() ;
        void load_textures_to_gpu() ;

        void get_shader_uniforms(GLuint shader_programme);
        void set_shader_uniforms(GLuint shader_programme /*, const mat4& modelMatrix*/, const vec3& ambient_color);
        void render(GLuint shader_programme);
#endif

		Node* node;
		
	};

	std::vector<Mesh> meshes;
	std::vector<Node> nodes;
	std::vector<std::string> names;

	static void load_default_textures() ;
    bool load_from_file(const char* file_path, const char* file_name, bool absolutePath = false, int index = 0) ;
    
#ifdef USE_OPENGL

	void load_to_gpu() ;

	void get_shader_uniforms(GLuint shader_programme);
	void set_shader_uniforms(GLuint shader_programme /*, const mat4& modelMatrix*/, const vec3& ambient_color);
    void render(GLuint shader_programme);
#endif
    
};
