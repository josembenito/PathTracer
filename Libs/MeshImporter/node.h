#pragma once
#include <vector>
#include "maths_funcs.h"

struct Node {

	Node* parent;
	std::vector<Node*> children;

    // local
	vec3 position;
	versor rotation;
	vec3 scale;

	mat4 localMatrix;
	mat4 localInverseMatrix;

    // world
	mat4 worldMatrix;
	mat4 worldInverseMatrix;

	Node();

	void init();
	void addChild(Node& node) ;
	void removeChild(Node& node) ;
	void updateLocal();
	void updateHierarchy();
};

