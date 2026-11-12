# {{PROJECT}}

언리얼 엔진 {{ENGINE_VERSION}}로 만드는 게임. 사용자와는 한국어로 대화한다.

## 게임

아직 정하지 않음. `/design 게임`으로 정한다. 정해지면 한 줄 소개, 핵심 재미 3가지, 기획서 경로(`docs/design/game.md`)를 여기에 적는다.

## 엔진과 명령

- 엔진: UE {{ENGINE_VERSION}}, `{{ENGINE_ROOT}}`. 스크립트는 엔진 폴더를 `Scripts/ue-root.ps1`로 자동으로 찾는다(바꾸려면 환경 변수 `UE_ROOT`).
- API 확인용 엔진 소스: `{{ENGINE_ROOT}}\Engine\Source`
- 빌드 (에디터를 닫은 상태): `Scripts\build.bat`
- 명령줄 테스트 (에디터를 닫은 상태): `Scripts\test.bat` (필터: `Scripts\test.bat {{PROJECT}}.Dash`)
- 에디터가 켜져 있을 때 컴파일: UE MCP의 `LiveCodingToolset.CompileLiveCoding`. `.cpp`만 바꿨을 때만 쓴다.
- 헤더, `UCLASS`/`UPROPERTY`/`UFUNCTION`, 새 파일을 바꿨으면 에디터를 닫고 `Scripts\build.bat`로 빌드한다.
- UE MCP 연결: `.mcp.json` (`unreal-mcp`, `http://127.0.0.1:8000/mcp`). 메인 대화는 대화를 시작할 때 에디터가 켜져 있어야 연결된다. `ue-editor`, `ue-qa`, `ue-programmer`는 부를 때마다 스스로 연결한다(에이전트 설정의 `mcpServers`, 이름 `unreal-editor`). 그래서 에디터 작업은 에이전트에게 맡긴다.
- 에디터 켜기와 끄기: 메인이 `Scripts\editor.bat open | close | status`로 한다. 켜기는 MCP 포트가 응답할 때까지 기다린다. 끄기 전에 저장한다(`ue-editor`나 메인의 MCP로 공식 툴셋 `AssetTools.save_assets`에 빈 목록을 넘기면 저장 안 된 에셋을 모두 저장한다). 끄기는 창의 X 버튼과 같아서, 저장 안 된 게 남아 있으면 에디터가 저장 창을 띄우고 스크립트는 기다리다 알린다. 강제로 끄지 않는다.
- 프로젝트 툴셋: 이름 `{{PROJECT}}Tools`, 위치 `Plugins/{{PROJECT}}Tools/` (파이썬, 첫 도구를 만들 때 생성), 테스트 러너 이름 `{{PROJECT}}.Tools`
- 일회용 에디터 스크립트 실행 (사용자가 승인한 것만): `Scripts\ue-python.bat Scripts\Editor\<파일>.py`

## 폴더

- `Source/{{PROJECT}}/<기능>/`: C++ 코드. 헤더는 `"<기능>/<파일>.h"`로 include한다(모듈 `Build.cs`에 `PublicIncludePaths.Add(ModuleDirectory);`가 있어야 한다)
- `Source/{{PROJECT}}/Tests/`: 자동 테스트. `#if WITH_DEV_AUTOMATION_TESTS`로 감싸고, 이름은 `{{PROJECT}}.<기능>.<동작>`. 항상 통과하는 최소 테스트 `{{PROJECT}}.Smoke`(`{{PROJECT}}SmokeSpec.cpp`)는 지우지 않는다.
- `/Game/<기능>/`: 에셋 (예: `/Game/Player/`, `/Game/Dash/`). 이름(접두사)과 하위 폴더는 `.claude/rules/ue-assets.md`
- `/Game/Tests/`: 테스트 맵과 테스트용 에셋
- `docs/design/`: 기획서. 게임 전체는 `game.md`, 기능은 `<기능>.md` (양식: `design` 스킬 폴더)
- `docs/tasks/`: 작업 카드 `NNN-<기능>-<이름>.md` (양식: `cards` 스킬 폴더)
- `docs/progress.md`: 진행 기록
- `Scripts/`: 빌드, 테스트 스크립트
- `Plugins/{{PROJECT}}Tools/Content/Python/`: 프로젝트 툴셋 (공식 툴셋에 없는 에디터 도구와 그 테스트)
- `Scripts/Editor/`: 한 번만 할 작업용 일회용 파이썬 스크립트. 메인이 쓰고, 사용자가 승인한 뒤에만 실행한다.

## 팀

메인 Claude는 기획 대화, 작업 쪼개기, C++ 구현, 서브에이전트 조율을 맡는다.

- `ue-editor`: 에디터 안 작업 전부. 메인도 에디터를 직접 조작하지 않고 맡긴다. 예외는 사용자가 승인한 일회용 스크립트 실행 하나뿐이다.
- `ue-qa`: 자동 테스트 작성과 실행, 플레이 체크리스트
- `ue-reviewer`: C++, 테스트 코드, 프로젝트 툴셋 검토. 코드를 바꾼 작업은 완료 전에 반드시 검토받는다. 읽기만 한다(훅이 쓰기와 git 읽기 외 명령을 막는다).
- `ue-programmer`: 서로 독립된 작업을 따로 맡길 때. `Source/`, `Plugins/`, `docs/tasks/`에만 쓴다(훅이 막는다).
- 로그 카테고리는 `Log{{PROJECT}}` 하나를 쓴다(`Source/{{PROJECT}}/{{PROJECT}}.h`). 기능마다 새로 만들지 않는다.

서브에이전트를 부를 때 브리프에 넣는 것: 작업 카드 경로, 이번에 할 일, 관련 파일, 이전 결과가 적힌 곳.

`ue-editor`가 "필요한 도구"를 보고하고 멈추면 `editor-tool-request` 스킬을 따른다. 우회하지 않고 프로젝트 툴셋에 도구를 만들고(에픽 `create-toolset` 권장), 한 번만 할 작업만 승인받은 일회용 스크립트로 한다.

## 작업 흐름

1. 기획: `/design <기능>`으로 사용자와 대화하며 `docs/design/<기능>.md`를 쓴다. 메인이 직접 하고, 확정 전 점검에만 서브에이전트를 쓴다.
2. 작업 카드: `/cards <기능>`으로 확정된 기획서를 `docs/tasks/`의 카드로 나눈다. 구현 방법은 `/work`가 카드를 시작할 때 정하고, 카드는 번호 순서대로 하나씩 진행한다.
3. 진행: `/work <카드>`로 카드 한 장을 카드 시작(구현 방법 정하기) → 구현 → C++ 검토(`ue-reviewer`) → `ue-editor` → `ue-qa` → 테스트 검토(`ue-reviewer`) → 사용자 플레이 확인 → 마무리(카드와 `docs/progress.md` 기록)까지 진행한다. 단계마다 카드의 "진행 기록"에 남기고, 대화가 끊기면 그 기록에서 이어서 한다.
   - 에디터는 메인이 켜고 끈다. 에디터 작업이나 플레이 확인 직전에 켜고, 빌드할 C++가 남았으면 빌드부터 한다. 빌드나 새 테스트 때문에 꺼야 하면 저장하고 끈다. 에디터가 닫히지 않으면(저장 창 등) 사용자에게 알린다. 에이전트는 에디터를 끄지 않는다.
4. 커밋은 사용자가 원할 때만 한다.

## 규칙

- 대화를 시작하거나 대화가 요약되면 대화 시작 훅(`.claude/hooks/session-start.sh`)이 진행 중인 카드, 다음 할 일, 커밋 안 한 변경을 알려 준다. 자세한 기록은 `docs/progress.md`에서 읽는다.
- C++은 `.claude/rules/ue-cpp.md` 규칙을 따른다(언리얼 기본, 에픽 코딩 표준, 읽기 쉬운 코드, 구조와 의존성). C++ 파일을 열면 자동으로 읽힌다.
- C++와 블루프린트 중 어디에 만들지는 `.claude/rules/ue-blueprint-cpp.md`를 따른다(C++가 기반, 블루프린트는 에셋 연결, 겉모습, UI 배치, 시제품).
- API가 확실하지 않으면 추측하지 말고 엔진 소스에서 실제 선언을 확인한다.
- `.uasset`/`.umap`은 파일로 직접 수정하지 않는다 (권한으로 막혀 있다).
- 기획 확정, 작업 시작, 에셋 삭제 같은 큰 결정은 사용자에게 먼저 묻는다.
- 에셋 여러 개를 바꾸는 에디터 작업 전에는 지금 상태를 커밋해 둘지 사용자에게 묻는다. MCP로 바꾼 내용은 되돌리기 어려울 수 있다.
- 커밋은 사용자가 요청할 때만 한다.
