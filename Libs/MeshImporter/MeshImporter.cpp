//
//  MeshImporter.cpp
//  MeshImporter
//
//  Created by Chema on 07/10/2020.
//

#include <iostream>
#include "MeshImporter.hpp"
#include "MeshImporterPriv.hpp"

void MeshImporter::HelloWorld(const char * s)
{
    MeshImporterPriv *theObj = new MeshImporterPriv;
    theObj->HelloWorldPriv(s);
    delete theObj;
};

void MeshImporterPriv::HelloWorldPriv(const char * s) 
{
    std::cout << s << std::endl;
};

