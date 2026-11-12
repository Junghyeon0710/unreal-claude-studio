// Minimal test that always passes. It confirms the automation test setup works
// and keeps the "{{PROJECT}}" test filter from matching zero tests. Do not delete.

#include "Misc/AutomationTest.h"

#if WITH_DEV_AUTOMATION_TESTS

BEGIN_DEFINE_SPEC(F{{PROJECT}}SmokeSpec, "{{PROJECT}}.Smoke", EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)
END_DEFINE_SPEC(F{{PROJECT}}SmokeSpec)

void F{{PROJECT}}SmokeSpec::Define()
{
	Describe("Setup", [this]()
	{
		It("runs project automation tests", [this]()
		{
			TestTrue(TEXT("Project automation tests run"), true);
		});
	});
}

#endif // WITH_DEV_AUTOMATION_TESTS
