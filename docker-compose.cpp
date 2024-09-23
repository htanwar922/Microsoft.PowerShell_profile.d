#include <iostream>
#include <cstdlib>
#include <string>

int main(int argc, char* argv[]) {
    std::string dockerCommand = "wsl -d Ubuntu -e docker-compose ";
    for (int i = 1; i < argc; ++i) {
        dockerCommand += argv[i];
        dockerCommand += " ";
    }
    std::string fullCommand = "pwsh.exe -Command \"" + dockerCommand + "\"";
    return system(fullCommand.c_str());
}
