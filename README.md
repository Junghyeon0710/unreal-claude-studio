# unreal-claude-studio

언리얼 엔진 5 1인 개발용 Claude Code 설정 모음입니다.

## 구조

메인 Claude(Opus)가 기획과 구현을 맡고, 서브에이전트가 검토, 에디터 작업, 테스트를 돕습니다.

| 서브에이전트 | 역할 | 언제 불리나 | 모델 |
|---|---|---|---|
| `ue-programmer` | 작업 카드 하나의 C++ 구현 | 독립된 작업을 따로 맡길 때 (병렬 작업 등) | 세션 모델 |
| `ue-editor` | 에디터 안 작업 (블루프린트, 입력, 레벨, 에셋). 도구가 없으면 우회하지 않고 필요한 도구를 보고함 | 에디터를 만질 때 항상 | Sonnet |
| `ue-qa` | 자동 테스트 작성과 실행, 플레이 체크리스트 | 구현이 끝났을 때 | Sonnet |
| `ue-reviewer` | C++, 테스트 코드, 프로젝트 툴셋 검토. 에픽 C++ 코딩 표준 기준 (지적만, 수정 안 함) | 코드가 바뀐 뒤, 작업 완료 전 | 세션 모델 |

파일은 `.claude/agents/`에 있습니다. 함께 쓰는 것:

- `.claude/rules/ue-cpp.md`: C++ 규칙(언리얼 기본, 에픽 C++ 코딩 표준, 읽기 쉬운 코드, 구조와 의존성). `Source/`, `Plugins/`의 C++ 파일을 열면 자동으로 읽힙니다. 메인, `ue-programmer`, `ue-qa`가 이 규칙으로 쓰고 `ue-reviewer`가 이 규칙으로 검토합니다.
- `.claude/rules/ue-blueprint-cpp.md`: C++와 블루프린트 나누기. 에픽 권장대로 C++를 기반으로 두고, 규칙, 판정, 숫자는 C++에, 에셋 연결, 겉모습 반응, UI 배치, 버리는 시제품은 블루프린트에 둡니다. C++ 파일을 열면 자동으로 읽히고, `/cards`가 카드를 시작할 때 읽습니다.
- `.claude/rules/ue-assets.md`: 에셋 이름(접두사)과 폴더. 에픽 문서 "Recommended Asset Naming Conventions"를 기본으로 하고, 문서에 없는 종류는 UE 5.8 템플릿을 따릅니다. 매 대화에 들어가고, `ue-editor`도 시작할 때 읽습니다.
- `.claude/skills/design/`: 기획실. `/design 게임` 또는 `/design <기능>`으로 메인이 사용자에게 한 번에 하나씩 묻고, 묶음마다 정리해서 승인받은 것만 `docs/design/`에 기획서로 씁니다. 정한 것과 이유를 기획서에 남겨서 새 대화에서도 기획서만 보고 구현할 수 있게 합니다. 게임 아이디어가 없으면 단서를 하나 묻고 한 줄 컨셉 2~3개를 제안합니다. 확정 전에 읽기 전용 서브에이전트가 "이것만 보고 만들 수 있나"를 점검합니다. 기획서 양식(게임, 기능)도 이 폴더에 있습니다.
- `.claude/skills/cards/`: 작업 카드. `/cards <기능>`으로 확정된 기능 기획서를 `docs/tasks/`의 카드 2~5장으로 나눕니다. 카드마다 기획서의 완료 조건이 빠짐없이 한 번씩 들어갑니다. 구현 방법(파일, 클래스와 함수 이름, C++와 블루프린트, 에디터 작업, 테스트 계획)은 그 카드를 시작할 때 정하고, 구조를 정하는 선택은 사용자에게 추천과 함께 묻습니다. 수치 조정이나 버그 같은 작은 일은 기획서 없이 카드 한 장으로 합니다. 카드 양식도 이 폴더에 있습니다.
- `.claude/skills/work/`: 카드 진행. `/work <카드>`로 카드 한 장을 구현 → `ue-editor` → `ue-qa` → `ue-reviewer` → 사용자 플레이 확인 → 마무리까지 진행합니다. 단계마다 카드의 "진행 기록"에 한 줄씩 남겨서, 대화가 끊기거나 요약돼도 그 기록에서 이어서 합니다. 에디터 켜고 끄기, 카드에 없는 구조 변경, 같은 문제로 3번 넘게 고칠 때, 플레이 확인, 커밋에서만 멈추고 묻습니다. 나머지는 메인이 정하고 `판단:`으로 기록합니다. 기능의 카드가 다 끝나면 회고를 해서 스튜디오에서 불편했던 점을 `docs/progress.md`의 "스튜디오 개선" 칸에 남깁니다.
- `.claude/skills/editor-tool-request/`: 공식 도구가 없을 때 메인이 따르는 절차
- `.claude/hooks/`: 에이전트 쓰기 범위와 명령을 막는 훅, 대화 시작 훅
- `.claude/hooks/session-start.sh`: 대화 시작 훅. 새 대화, `/clear`, 대화 요약 직후, 이어 하기 때 진행 중인 카드(상태와 마지막 진행 기록), 대기 카드 수, `docs/progress.md`의 "다음 할 일", 브랜치와 커밋 안 한 변경 수를 메인의 맥락에 넣습니다. 화면에는 보이지 않습니다. `docs/tasks/`와 `docs/progress.md`가 둘 다 없으면 아무것도 넣지 않습니다.
- `.claude/settings.json`: 에셋 파일(`.uasset`, `.umap`)을 파일로 직접 고치지 못하게 막는 설정. 에셋은 에디터에서만 바꿉니다. 대화 시작 훅도 여기서 연결합니다.

## 요구 사항

- 언리얼 엔진 5 (5.8 기준으로 작성)
- 에디터 작업과 Live Coding 컴파일에는 UE `ModelContextProtocol`과 `AllToolsets` 플러그인이 필요합니다. 에이전트는 UE가 제공하는 공식 툴셋(`Engine/Plugins/Experimental/Toolsets/`)만 사용합니다.
- 언리얼 프로젝트 루트의 `CLAUDE.md`에 엔진 경로, 빌드 명령, 테스트 폴더를 적어야 합니다.
- 에픽이 만든 Claude Code 플러그인 `unreal-engine-skills-for-claude-code` (공식 마켓플레이스). 에이전트가 이 플러그인의 `unreal-mcp`, `create-toolset` 스킬을 씁니다.
- `bash` (Windows는 Git Bash). 에이전트 훅에 씁니다. `write-guard.sh`는 에이전트마다 정해진 프로젝트 폴더 밖에 쓰지 못하게 막습니다(`ue-editor`, `ue-reviewer`: 자기 기억 폴더 / `ue-qa`: 테스트 폴더, `docs/tasks/`, 기억 폴더 / `ue-programmer`: `Source/`, `Plugins/`, `docs/tasks/`). 엔진 폴더나 다른 프로젝트도 막힙니다. 훅은 `${CLAUDE_PROJECT_DIR}`로 스크립트를 찾아서 작업 폴더가 바뀌어도 동작하고, `onFailure: block`이라 훅이 실행되지 못하면 통과시키지 않고 막습니다(Claude Code 2.1.295 이상). `readonly-git-guard.sh`는 `ue-reviewer`의 Bash를 git 읽기 명령으로 제한합니다. 프로젝트 폴더를 신뢰한다고 승인해야 훅이 동작합니다.
- (선택) Python Remote Execution: 프로젝트 설정 > 플러그인 > Python > "Enable Remote Execution?". 프로젝트 툴셋을 에디터 재시작 없이 다시 불러오거나 일회용 스크립트를 실행할 때 필요합니다. 기본값은 내 PC 안에서만 통신하지만(127.0.0.1), 내 PC의 다른 프로그램도 에디터에 코드를 보낼 수 있게 됩니다.

## 도구가 없을 때

에픽 권장(`create-toolset` 스킬)대로 우회하지 않고 도구를 만듭니다.

1. `ue-editor`가 "필요한 도구"(하는 일, 입력, 출력)를 보고하고 멈춥니다.
2. 메인이 사용자에게 묻고, 승인받으면 프로젝트 툴셋(파이썬 우선)에 도구와 테스트를 만듭니다.
3. `ue-reviewer` 검토 → 에디터에 반영(`ModelContextProtocol.RefreshTools`) → 같은 `ue-editor`가 새 도구로 이어서 작업합니다.
4. 한 번 만든 도구는 공식 도구처럼 계속 씁니다.

한 번만 할 작업(예: 에셋 수백 개 이름 일괄 변경)만 예외로, 메인이 일회용 스크립트를 쓰고 승인받은 뒤 `Scripts/ue-python.bat`로 실행합니다. 자세한 절차는 `editor-tool-request` 스킬에 있습니다.

## 사용법

1. 언리얼 프로젝트 루트에 `.claude` 폴더와 `Scripts` 폴더를 복사합니다.
2. `Scripts/ue-python.bat`의 `UE_ROOT`를 자기 엔진 경로로 바꿉니다.
3. 프로젝트 `CLAUDE.md`에 적습니다.
   - "게임" 칸 (처음에는 비워 두고 `/design 게임`으로 채웁니다), 기획서 폴더 `docs/design/`, 작업 카드 폴더 `docs/tasks/` (두 폴더는 비어 있어도 만들어 둡니다), 진행 기록 `docs/progress.md` ("다음 할 일" 칸을 두면 대화 시작 훅이 보여 줍니다)
   - 프로젝트 툴셋 이름과 위치 (예: `ProjectATools`, `Plugins/ProjectATools/`). 툴셋 테스트 러너 이름은 `<프로젝트>.Tools`로 정해서 프로젝트 테스트 필터에 걸리게 합니다.
   - 테스트 폴더와 명령줄 테스트 명령. 항상 통과하는 최소 테스트 `<프로젝트>.Smoke`를 하나 두면 테스트 설정을 확인할 수 있고, 필터에 걸리는 테스트가 0개라서 실패하는 일도 없습니다.
   - "`ue-editor`가 필요한 도구를 보고하면 `editor-tool-request` 스킬을 따른다", "C++은 `.claude/rules/ue-cpp.md`를 따른다"
   - 에셋 여러 개를 바꾸는 작업 전에는 커밋할지 묻는다는 규칙 (에픽 보안 안내)
