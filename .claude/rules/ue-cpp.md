---
paths:
  - "Source/**/*.{h,cpp}"
  - "Plugins/**/*.{h,cpp}"
---

# UE C++ 규칙

이 프로젝트의 C++ 코드는 모두 이 규칙을 따른다. 메인, `ue-programmer`, `ue-qa`(테스트 코드)가 이 규칙으로 쓰고, `ue-reviewer`가 이 규칙으로 검토한다. `Source/`나 `Plugins/`의 `.h`, `.cpp` 파일을 열거나 고치면 자동으로 읽힌다.

## 언리얼 기본

- 리플렉션: `UCLASS`/`USTRUCT`/`UENUM`/`UPROPERTY`/`UFUNCTION`과 `GENERATED_BODY()`를 정확히 쓴다.
- 이름 접두사: `A`(액터), `U`(UObject), `F`(구조체, 일반 타입), `E`(enum), `I`(인터페이스), `T`(템플릿), `b`(bool 변수).
- UObject 포인터 멤버는 `UPROPERTY()`와 `TObjectPtr<>`로 들고 있는다. `UPROPERTY`가 없으면 가비지 컬렉션에 지워질 수 있다. 소유하지 않는 참조는 `TWeakObjectPtr<>`.
- 생성: `NewObject<>()`, 생성자에서는 `CreateDefaultSubobject<>()`, 액터는 `SpawnActor`. `new`/`delete` 금지.
- UObject가 아닌 객체: `TSharedPtr`/`TUniquePtr`/`TWeakPtr`.
- 컨테이너와 문자열: `TArray`/`TMap`/`TSet`. 식별자는 `FName`, 화면에 보이는 글자는 `FText`, 문자열 조작은 `FString`.
- 조절할 값은 코드에 박지 않는다. `UPROPERTY(EditDefaultsOnly, Category = "...")` 등으로 노출해서 블루프린트나 데이터에서 조절하게 한다.
- Tick은 꼭 필요할 때만 쓴다. 가능하면 타이머(`FTimerHandle`), 델리게이트, 이벤트를 쓰고, 안 쓰면 `PrimaryActorTick.bCanEverTick = false`.
- 오버라이드에서 `Super::` 호출을 빠뜨리지 않는다 (`BeginPlay`, `EndPlay`, `Tick` 등).
- 바인딩한 델리게이트와 타이머는 `EndPlay`에서 정리한다.
- 포인터는 쓰기 전에 `IsValid()` 또는 `nullptr`을 확인한다. `check()`는 절대 일어나면 안 되는 경우에만 쓴다.
- 입력은 Enhanced Input(`UInputAction`, `UInputMappingContext`)을 쓴다.
- 바로 필요하지 않은 에셋 참조는 `TSoftObjectPtr<>`/`TSoftClassPtr<>`.
- 블루프린트 연결점: `BlueprintCallable`, `BlueprintImplementableEvent`, `BlueprintNativeEvent`(+ `_Implementation`).
- 로그는 프로젝트 로그 카테고리 `Log<프로젝트>`(예: `LogProjectA`, 모듈 헤더 `<프로젝트>.h`에 선언)로 `UE_LOG`를 남긴다. 아직 없으면 그것부터 만들고, 기능마다 새 카테고리를 만들지 않는다.
- 헤더에는 최소한만 include하고 가능하면 전방 선언을 쓴다. 필요한 include는 `.cpp`에서 한다. 다른 헤더를 거쳐 들어오는 include에 기대지 않는다.
- API가 확실하지 않으면 추측하지 않는다. `CLAUDE.md`에 적힌 엔진 경로 아래 `Engine/Source`에서 실제 선언을 검색해서 확인한다.

## 에픽 C++ 코딩 표준에서 특히 지킬 것

- 나중에 실행되는 람다(타이머, 델리게이트, 비동기)는 `[this]`나 참조로 캡처하지 않는다. `CreateWeakLambda`나 `TWeakObjectPtr`를 쓴다. 지워진 객체에서 람다가 실행되면 크래시가 난다.
- 람다 캡처는 명시적으로 쓴다(`[&]`, `[=]` 금지).
- 오버라이드에는 `virtual`과 `override`를 함께 쓴다.
- `NULL` 대신 `nullptr`을 쓴다.
- 바꾸지 않는 인자는 `const` 참조로 받고, 객체를 바꾸지 않는 메서드에는 `const`를 붙인다.
- 문자열 리터럴은 `TEXT()`로 감싼다.
- `auto`는 람다, 긴 반복자 타입 정도에만 쓴다. 읽는 사람이 타입을 알 수 있게 한다.
- 출력 인자에는 `Out` 접두사를 붙인다(`bOutFound`).
- 컴파일러 경고는 끄지 말고 고친다.

## 읽기 쉬운 코드 (클린 코드 원칙을 언리얼에 맞게)

`ue-reviewer`는 이 부분을 "권장"으로 지적한다.

- 함수 하나는 한 가지 일만 한다. 길어지면 이름 있는 작은 함수로 나눈다.
- 이름만 봐도 무엇인지 알 수 있게 짓는다. 줄임말을 피한다(`Dist`보다 `DashDistance`). 이름 모양은 에픽 표준(PascalCase, 접두사)을 따른다.
- 기능은 컴포넌트로 나눈다. 액터 하나에 기능을 다 넣지 않고, 다른 액터에서도 쓸 만한 기능은 `UActorComponent`로 만든다(예: 대시는 `UDashComponent`).
- 같은 코드를 여러 곳에 복사하지 않는다. 두 번 이상 쓰이면 함수로 뺀다. 엔진에 이미 있는 기능은 다시 만들지 않는다.
- 조건문을 깊게 겹치지 않는다. 안 되는 경우를 먼저 확인하고 일찍 돌아간다.
- 무엇을 하는지는 코드만 보고 알 수 있게 쓰고, 왜 이렇게 했는지와 어떤 제약 때문인지는 주석으로 남긴다. 6개월 뒤에 다시 봐도 의도를 빨리 알 수 있게 하기 위해서다. 코드를 그대로 읽어주는 주석은 쓰지 않고, 헷갈리는 코드는 주석보다 먼저 고쳐 쓴다.
- C++에서는 예외(exception)를 쓰지 않는다. 실패할 수 있는 함수는 `bool`이나 `TOptional`로 알리고, 잘못된 상태는 `ensure`(로그 남기고 계속)나 `check`(절대 일어나면 안 될 때)로 잡는다.

## 구조와 의존성

사용자가 정리한 설계 노트([UnrealEngineLab `Docs/CS`](https://github.com/Junghyeon0710/UnrealEngineLab/tree/main/Docs/CS))를 이 프로젝트 규칙으로 옮긴 것이다. `ue-reviewer`는 이 부분을 주로 "권장"으로 지적하고, 버그로 이어지는 것만 "꼭 고칠 것"으로 올린다.

- **누가 누구를 부르나**
  - Owner(예: 캐릭터)가 자기가 가진 컴포넌트에 일을 시킬 때는 직접 호출한다.
  - 컴포넌트가 "이런 일이 생겼어"를 알릴 때는 Delegate를 쓴다(예: `OnHealthChanged`). 컴포넌트가 Owner의 구체 함수를 직접 부르지 않는다.
  - "이것 해줘"라는 요청은 직접 호출한다. 구체 타입을 모르는 여러 객체에 같은 일을 시킬 때는 `UInterface`를 쓴다.
  - 형제 컴포넌트에 일을 시킬 때는 `FindComponentByClass`로 찾아서 명령하지 않는다. 결과를 Delegate로 알리고 Owner가 조율한다. 값을 읽기만 하는 조회는 직접 해도 되지만, 다른 객체의 상태를 직접 바꾸지 않는다.
  - 함수는 자기 일만 하고 나머지는 알린다. 예: `AddItem()`은 아이템만 넣고 Delegate로 알린다. UI 갱신, 퀘스트, 저장은 각 시스템이 받아서 처리한다.
  - 한 Owner에서만 쓰고 다시 쓸 계획이 없는 컴포넌트는 그 Owner의 구체 타입을 알아도 된다.
- **Owner는 조율, 컴포넌트는 기능.** Owner에는 누가 언제 무엇을 할지만 두고, 계산과 세부 기능은 컴포넌트에 둔다. Owner의 조율 코드가 계속 커지면 별도 시스템(`UWorldSubsystem`, `UGameInstanceSubsystem` 등)으로 옮길지 검토한다. 모든 것을 아는 클래스(God Object)를 만들지 않는다.
- **과하게 나누지 않는다.** 인터페이스, 이벤트, 매니저를 "나중에 필요할지도"라는 이유로 미리 만들지 않는다. 함수나 클래스를 나눌 때는 네 가지를 본다. 따로 의미가 있나, 이름을 붙이면 이해가 쉬워지나, 다시 쓸 일이 있나, 따로 바뀔 수 있나. 이벤트는 결합을 줄이지만 흐름을 따라가기 어렵게 만든다는 점도 함께 따진다. 고른 구조의 이유를 설명할 수 있어야 한다.
- **확장과 상속.** 종류를 하나 추가할 때마다 여러 곳의 코드를 고쳐야 한다면, `UDataAsset`이나 `UDataTable`로 데이터에서 늘리는 방법을 먼저 검토한다. 상속은 자식이 부모가 약속한 동작을 그대로 지킬 때만 쓴다. 그렇지 않거나 상속이 깊어지면 컴포넌트나 `UInterface`로 바꾼다. 인터페이스는 기능 단위로 작게 나눈다.
- **상태.** 상태가 적고 전환이 단순하면 `enum class`와 `switch`로 시작한다. 상태별 진입, 갱신, 종료 코드가 커지면 State 패턴으로 옮기고, 계층과 조건이 복잡해지면 StateTree를 검토한다.
- **클래스 모양.**
  - 선언 순서는 public, protected, private이다. 관련 있는 함수와 데이터는 가까이 둔다.
  - 멤버 변수는 기본으로 private에 둔다. 블루프린트에서 봐야 하는 private `UPROPERTY`는 `meta = (AllowPrivateAccess = "true")`를 쓴다. 파생 클래스에 필요하면 protected 변수보다 protected 접근 함수를 먼저 검토한다.
  - 상속할 계획이 없는 클래스에는 `final`을 붙인다.
  - 헤더끼리 서로 include하지 않는다. 포인터와 참조만 필요하면 전방 선언을 쓰고 include는 `.cpp`에서 한다. `.cpp`는 자기 헤더를 맨 먼저 include한다.
  - 관련된 여러 값은 Struct로 묶어서 넘긴다.
  - `FORCEINLINE`과 헤더 안 구현은 성능상 근거가 있을 때만 쓴다.
