"""Run one approved editor Python script inside the running Unreal Editor.

Uses Epic's Python Remote Execution (PythonScriptPlugin). The editor must be
running with "Enable Remote Execution?" turned on in Project Settings > Plugins > Python.
Called by ue-python.bat. Usage: ue_python.py <engine root> <project dir> <script.py>
"""

import pathlib
import sys
import time

TIMEOUT_SECONDS = 10


def main() -> int:
    if len(sys.argv) != 4:
        print("Usage: ue-python.bat <script.py>")
        return 2

    engine_root = pathlib.Path(sys.argv[1])
    project_dir = pathlib.Path(sys.argv[2]).resolve()
    script = pathlib.Path(sys.argv[3]).resolve()

    if script.suffix != ".py" or not script.is_file():
        print(f"Script not found: {script}")
        return 2

    sys.path.insert(0, str(engine_root / "Engine/Plugins/Experimental/PythonScriptPlugin/Content/Python"))
    import remote_execution  # pylint: disable=import-outside-toplevel

    session = remote_execution.RemoteExecution()
    session.start()
    try:
        node = find_editor(session, project_dir)
        if node is None:
            print("Unreal Editor for this project was not found. "
                  "Check that the editor is open and Python Remote Execution is enabled.")
            return 3

        session.open_command_connection(node["node_id"])
        # Quote the path: it contains spaces, and the plugin reads quoted .py paths as files.
        result = session.run_command(f'"{script}"', unattended=True,
                                     exec_mode=remote_execution.MODE_EXEC_FILE)
    finally:
        session.stop()

    for entry in result.get("output", []):
        print(f"[{entry.get('type', 'Info')}] {entry.get('output', '')}")
    if result.get("result") and result["result"] != "None":
        print(f"[Result] {result['result']}")

    if not result.get("success"):
        print("FAILED")
        return 1
    print("OK")
    return 0


def find_editor(session, project_dir: pathlib.Path):
    """Wait for the editor that has this project open to answer discovery."""
    deadline = time.time() + TIMEOUT_SECONDS
    while time.time() < deadline:
        for node in session.remote_nodes:
            root = node.get("project_root")
            if root and pathlib.Path(root).resolve() == project_dir:
                return node
        time.sleep(0.2)
    return None


if __name__ == "__main__":
    sys.exit(main())
