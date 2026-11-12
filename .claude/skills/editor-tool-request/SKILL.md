---
name: editor-tool-request
description: "Use when the ue-editor subagent stops with a '필요한 도구' block, or an editor task cannot be done with the official Unreal toolsets. By default adds the tool to the project toolset following Epic's create-toolset skill; for one-time bulk work only, runs an approved one-off Python script. ue-editor가 '필요한 도구'를 보고하면 이 순서로 처리한다."
---

# 공식 도구가 없을 때

`ue-editor`가 "필요한 도구"(하는 일, 입력, 출력, 확인한 툴셋, 한 번만 할 일인가)를 보고하고 멈췄을 때 메인이 이 순서로 처리한다. 에픽 권장(`create-toolset` 스킬)대로 우회하지 않고 도구를 만든다. 한 번만 할 작업만 일회용 스크립트로 한다.

프로젝트 툴셋 이름과 위치, 명령줄 테스트 명령은 `CLAUDE.md`에 적혀 있다.

## 기본: 프로젝트 툴셋에 도구 추가

1. 사용자에게 만들 도구(하는 일, 입력, 출력)를 보여주고 만들지 묻는다.
2. 승인하면 `create-toolset` 스킬을 불러와서 따른다. 파이썬을 먼저 쓰고, 파이썬 API로 안 되면 C++로 할지 사용자에게 묻는다. 엔진 API가 없어서 둘 다 안 되면 멈추고 알린다. 직접 만들거나 `ue-programmer`에게 맡긴다.
3. 툴셋 테스트를 함께 만든다. 테스트 러너 이름은 `<프로젝트>.Tools`로 정한다(`unreal.PythonTestRunner.create('<프로젝트>.Tools', ...)`). 그래야 명령줄 테스트의 기본 필터에 함께 걸린다.
4. `ue-reviewer`에게 검토받는다.
5. 에디터에 반영한다.
   - 첫 도구는 플러그인이 새로 생기므로 저장하고 `Scripts\editor.bat close`로 끈 뒤 `open`으로 다시 켠다.
   - 그다음부터는 Python Remote Execution이 켜져 있으면 에픽의 `reload_remote.py`(엔진 `Engine/Plugins/Experimental/ToolsetRegistry/Content/Python/toolset_registry/tests/`)로 다시 불러올 수 있다. 꺼져 있으면 에디터를 다시 켠다.
   - 반영한 뒤 에디터 콘솔에서 `ModelContextProtocol.RefreshTools`를 실행하고 Claude Code의 MCP를 다시 연결한다.
6. SendMessage로 같은 `ue-editor`에게 새 도구 이름을 보내 멈췄던 곳부터 이어서 하게 한다.

## 예외: 한 번만 할 작업은 일회용 스크립트

`ue-editor`가 "한 번만 할 일"이라고 했고 사용자도 동의할 때만 쓴다(예: 기존 에셋 수백 개의 이름 일괄 변경).

1. 메인이 `Scripts/Editor/<작업 카드 번호>-<할 일>.py`를 쓴다.
   - `import unreal`과 파이썬 표준 라이브러리만 쓴다. 파일 삭제, 프로젝트 밖 파일 접근, 네트워크, `subprocess`는 쓰지 않는다.
   - 바꾸는 부분은 `with unreal.ScopedEditorTransaction("<설명>"):` 안에 넣어서 Ctrl+Z로 되돌릴 수 있게 한다.
   - 브리프에 있는 에셋만 바꾸고, `unreal.get_editor_subsystem(unreal.EditorAssetSubsystem).save_loaded_asset()`으로 저장한다.
   - 결과는 `unreal.log()`로 남긴다.
2. 사용자에게 스크립트의 핵심 부분과 바뀌는 에셋을 보여주고 실행할지 묻는다. 승인은 그 스크립트를 한 번 실행하는 데만 쓴다. 승인 뒤 파일이 바뀌었으면 다시 묻는다.
3. 승인하면 에디터가 켜진 상태에서 `Scripts\ue-python.bat <파일>`로 실행하고, 결과를 SendMessage로 같은 `ue-editor`에게 보내 마무리하게 한다.
4. 에디터를 못 찾는다는 오류가 나면 Python Remote Execution(프로젝트 설정 > 플러그인 > Python > "Enable Remote Execution?")이 꺼져 있는 것이다. 사용자에게 켜 달라고 하거나, 에디터 아래쪽 출력 로그의 명령 칸에 `py "<스크립트 전체 경로>"`를 입력해서 직접 실행해 달라고 안내한다.

## 거절하면

그 작업은 사용자가 에디터에서 직접 하도록 할 일 목록으로 정리해 준다.
