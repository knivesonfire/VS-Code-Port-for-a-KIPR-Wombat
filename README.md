# Botball Code 2026 

Note: (after the 2026 summer) Under https://www.kipr.org/gcer/about-gcer/gcer-resources and under 2026 resources the paper "Modernizing robotics development by integrating Visual Studio Code and using SSH to deploy code to the KIPR wombat" has the explanation behind the code


### How to Use

1. Press Command Shift P to open the command palette 
2. Type `Tasks: Run Task`
3. Select `Setup Wombat` (choose `Unix` or `Windows` depending on your OS). You only need to run this command once for each computer and each wombat.
4. Press Command Shift P to open the command palette again
5. Type `Tasks: Run Task`
6. Select `Deploy to Wombat` (choose `Unix` or `Windows` depending on your OS). This will copy the code to the wombat. You need to run this command every time you want to update the code on the wombat.
7. Open the KIPR IDE at `http://192.168.125.1:8888/`
8. Select the `Botball` project and click `Compile Botball`
9. Click `Run` to run the code on the wombat

### Notes
- When including a file do not put the folder path. For example, if you want to include `src/mechanisms/drive/Controller.c`, you should write `#include "Controller.h"` instead of `#include "mechanisms/drive/Controller.h"`.
