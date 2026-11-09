# unreal-claude-studio

언리얼 엔진 5 1인 개발용 Claude Code 설정 모음입니다.

## 구조

메인 Claude(Opus)가 기획과 구현을 맡고, 서브에이전트가 검토, 에디터 작업, 테스트를 돕습니다.

| 서브에이전트 | 역할 | 언제 불리나 | 모델 |
|---|---|---|---|
| `ue-programmer` | 작업 카드 하나의 C++ 구현 | 독립된 작업을 따로 맡길 때 (병렬 작업 등) | 세션 모델 |
| `ue-editor` | 에디터 안 작업 (블루프린트, 입력, 레벨, 에셋). 도구가 없으면 우회하지 않고 필요한 도구를 보고함 | 에디터를 만질 때 항상 | Sonnet |
| `ue-qa` | 자동 테스트 작성과 실행, 플레이 체크리스트 | 구현이 끝났을 때 | Sonnet |
| `ue-reviewer` | C++ 검토 (지적만, 수정 안 함) | C++이 바뀐 뒤, 작업 완료 전 | 세션 모델 |

파일은 `.claude/agents/`에 있습니다.

## 요구 사항

- 언리얼 엔진 5 (5.8 기준으로 작성)
- 에디터 작업과 Live Coding 컴파일에는 UE `ModelContextProtocol`과 `AllToolsets` 플러그인이 필요합니다. 에이전트는 UE가 제공하는 공식 툴셋(`Engine/Plugins/Experimental/Toolsets/`)만 사용합니다.
- 언리얼 프로젝트 루트의 `CLAUDE.md`에 엔진 경로, 빌드 명령, 테스트 폴더를 적어야 합니다.
- 에픽이 만든 Claude Code 플러그인 `unreal-engine-skills-for-claude-code` (공식 마켓플레이스). 에이전트가 이 플러그인의 `unreal-mcp`, `create-toolset` 스킬을 씁니다.
- `bash` (Windows는 Git Bash). `ue-editor`의 훅(`.claude/hooks/ue-editor-write-guard.sh`)이 기억 폴더 밖 쓰기를 막는 데 씁니다. 프로젝트 폴더를 신뢰한다고 승인해야 훅이 동작합니다.
- (선택) Python Remote Execution: 프로젝트 설정 > 플러그인 > Python > "Enable Remote Execution?". 프로젝트 툴셋을 에디터 재시작 없이 다시 불러오거나 일회용 스크립트를 실행할 때 필요합니다. 기본값은 내 PC 안에서만 통신하지만(127.0.0.1), 내 PC의 다른 프로그램도 에디터에 코드를 보낼 수 있게 됩니다.

## 도구가 없을 때

에픽 권장(`create-toolset` 스킬)대로 우회하지 않고 도구를 만듭니다.

1. `ue-editor`가 "필요한 도구"(하는 일, 입력, 출력)를 보고하고 멈춥니다.
2. 메인이 사용자에게 묻고, 승인받으면 프로젝트 툴셋(파이썬 우선)에 도구와 테스트를 만듭니다.
3. `ue-reviewer` 검토 → 에디터에 반영(`ModelContextProtocol.RefreshTools`) → 같은 `ue-editor`가 새 도구로 이어서 작업합니다.
4. 한 번 만든 도구는 공식 도구처럼 계속 씁니다.

한 번만 할 작업(예: 에셋 수백 개 이름 일괄 변경)만 예외로, 메인이 일회용 스크립트를 쓰고 승인받은 뒤 `Scripts/ue-python.bat`로 실행합니다.

## 사용법

1. 언리얼 프로젝트 루트에 `.claude` 폴더와 `Scripts` 폴더를 복사합니다.
2. `Scripts/ue-python.bat`의 `UE_ROOT`를 자기 엔진 경로로 바꿉니다.
3. 프로젝트 `CLAUDE.md`에 적습니다.
   - 프로젝트 툴셋 이름과 위치 (예: `ProjectATools`, `Plugins/ProjectATools/`)
   - "도구가 없을 때" 흐름과 일회용 스크립트 규칙
   - 에셋 여러 개를 바꾸는 작업 전에는 커밋할지 묻는다는 규칙 (에픽 보안 안내)
