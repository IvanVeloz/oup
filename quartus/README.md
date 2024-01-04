## Quartus Prime project directory

Initiate the Quartus Prime project by sourcing the `oup.tcl` file in this directory, then opening the newly created project.

### How to update out.tcl
Make whatever changes you need to the project (for example adding files, or chaing pin assignments and constraints). Then, follow the steps below.
1. Verify you haven't changed any personal settings in the project that you don't to publish.
2. Organize the settings file by clicking `Project > Organize Quartus Prime Settings File`.
3. Generate the TCL file by clicking `Project > Generate TCL File for Project...`.
4. Inspect what has changed in the file using `git diff`. Make sure that the changes in the file correspond to your intentions.

#### If you have a different board or project settings
If you must change your project settings or assignments to support a different board or setup, then you will have:
1. Generate a TCL file with a different name.
2. Inspect the differences against `out.tcl` using a file comparison tool such as `diff`.
3. Modify `out.tcl` manually with your intended changes.
4. Create a new project from the `out.tcl` you just changed.
5. Verify everything is okay.
6. Follow the regular procedure on "How to update out.tcl", to make sure the `out.tcl` stays organized.
