import XCTest
@testable import RedactoConsentSDK

/// Port of the React SDK's `chromeCopy.test.ts`.
final class NoticeChromeCopyTests: XCTestCase {
    private let english = NoticeChromeCopy.english

    private func strings(_ copy: NoticeChromeCopy) -> [String: String] {
        [
            "yes": copy.yes,
            "no": copy.no,
            "mixed": copy.mixed,
            "savedAnswer": copy.savedAnswer,
            "confirmAcceptAllTitle": copy.confirmAcceptAllTitle,
            "confirmAcceptAllDetail": copy.confirmAcceptAllDetail,
            "confirmAcceptSelectedTitle": copy.confirmAcceptSelectedTitle,
            "confirmAcceptSelectedDetail": copy.confirmAcceptSelectedDetail,
            "confirmDeclineTitle": copy.confirmDeclineTitle,
            "confirmDeclineDetail": copy.confirmDeclineDetail,
            "otpTitle": copy.otpTitle,
            "otpDescription": copy.otpDescription,
            "otpSubmit": copy.otpSubmit,
            "otpVerifying": copy.otpVerifying,
            "otpFailed": copy.otpFailed,
            "productPoliciesLabel": copy.productPoliciesLabel,
            "hintNothingChosen": copy.hintNothingChosen,
            "hintNothingEngaged": copy.hintNothingEngaged,
            "hintRequiredOutstanding": copy.hintRequiredOutstanding,
        ]
    }

    func testAnswersInTheNoticesLanguageByDisplayName() {
        let hindi = NoticeChromeCopy.forLanguage("Hindi")
        XCTAssertEqual(hindi.yes, "हाँ")
        XCTAssertEqual(hindi.no, "नहीं")
    }

    func testAnswersToACodeAsWellAsADisplayName() {
        XCTAssertEqual(NoticeChromeCopy.forLanguage("hi"), NoticeChromeCopy.forLanguage("Hindi"))
    }

    func testFallsBackToEnglishForALanguageItDoesNotCarry() {
        XCTAssertEqual(NoticeChromeCopy.forLanguage("Klingon"), english)
        XCTAssertEqual(NoticeChromeCopy.forLanguage(nil), english)
        XCTAssertEqual(NoticeChromeCopy.forLanguage(""), english)
    }

    func testCoversEveryLanguageTheNoticeCanBeReadIn() {
        XCTAssertEqual(NoticeChromeCopy.languages.count, 23)
        XCTAssertEqual(Set(NoticeChromeCopy.languages), Set(NoticeLanguageCodes.nameToBcp47.values))
    }

    // A bundle missing a string would render an empty slot where English
    // renders copy.
    func testEveryBundleCarriesEveryString() {
        for language in NoticeChromeCopy.languages {
            for (key, value) in strings(NoticeChromeCopy.forLanguage(language)) {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespaces).isEmpty, "\(language).\(key)")
            }
        }
    }

    func testEveryOtherLanguageTranslatesWhatTheVisitorReads() {
        for language in NoticeChromeCopy.languages where language != "en" {
            let copy = NoticeChromeCopy.forLanguage(language)
            XCTAssertNotEqual(copy.yes, english.yes, language)
            XCTAssertNotEqual(copy.no, english.no, language)
            XCTAssertNotEqual(copy.confirmAcceptSelectedTitle, english.confirmAcceptSelectedTitle, language)
            XCTAssertNotEqual(copy.otpTitle, english.otpTitle, language)
        }
    }

    func testKeepsTheAnswerPlaceholderEveryBundleNeeds() {
        for language in NoticeChromeCopy.languages {
            XCTAssertTrue(NoticeChromeCopy.forLanguage(language).savedAnswer.contains("{answer}"), language)
        }
        XCTAssertEqual(english.savedAnswer("Yes"), "Saved answer: Yes")
    }

    // The part-answered row sits in the dropdown's fixed slot beside Yes and No.
    func testKeepsThePartAnsweredPlaceholderShortEnoughForTheSlot() {
        for language in NoticeChromeCopy.languages {
            let mixed = NoticeChromeCopy.forLanguage(language).mixed
            XCTAssertFalse(mixed.trimmingCharacters(in: .whitespaces).isEmpty, language)
            XCTAssertLessThanOrEqual(mixed.utf16.count, 8, language)
        }
    }

    // "Mixed" is what a design tool calls a multi-selection, not language a
    // data principal reads on a consent notice.
    func testDoesNotLabelItWithTheDesignToolTerm() {
        XCTAssertEqual(english.mixed, "Partly")
        XCTAssertEqual(SelectionControlCopy.mixed, "Partly")
        for language in NoticeChromeCopy.languages {
            XCTAssertNotEqual(NoticeChromeCopy.forLanguage(language).mixed.lowercased(), "mixed", language)
        }
    }

    func testResolvesFromTheNameTheLanguageMenuHolds() {
        for name in NoticeLanguageCodes.nativeLabels.keys {
            let copy = NoticeChromeCopy.forLanguage(name)
            if name == "English" {
                XCTAssertEqual(copy, english)
            } else {
                XCTAssertNotEqual(copy.yes, english.yes, name)
            }
        }
    }

    func testResolvesABareOrRegionTaggedCodeOntoTheSameBundle() {
        XCTAssertEqual(NoticeChromeCopy.forLanguage("mni"), NoticeChromeCopy.forLanguage("mni-Mtei"))
        XCTAssertEqual(NoticeChromeCopy.forLanguage("pa-IN"), NoticeChromeCopy.forLanguage("Punjabi"))
        XCTAssertEqual(NoticeChromeCopy.forLanguage("en-US"), english)
    }

    func testResolvesACodeWhateverItsCase() {
        XCTAssertEqual(NoticeChromeCopy.forLanguage("HI-IN"), NoticeChromeCopy.forLanguage("Hindi"))
        XCTAssertEqual(NoticeChromeCopy.forLanguage("HI"), NoticeChromeCopy.forLanguage("hi"))
        XCTAssertEqual(NoticeChromeCopy.forLanguage("Pa-In"), NoticeChromeCopy.forLanguage("Punjabi"))
        XCTAssertEqual(NoticeChromeCopy.forLanguage("MNI-MTEI"), NoticeChromeCopy.forLanguage("mni-Mtei"))
    }

    func testNamesTheConfirmDialogPerAction() {
        let hindi = NoticeChromeCopy.forLanguage("Hindi")
        XCTAssertEqual(hindi.confirmTitle(.acceptAll), hindi.confirmAcceptAllTitle)
        XCTAssertEqual(hindi.confirmDetail(.decline), hindi.confirmDeclineDetail)
        XCTAssertEqual(ConfirmDialogCopy.title(for: .acceptSelected), "Confirm your selections?")
    }

    func testTranslatesTheConfirmHints() {
        let hindi = NoticeChromeCopy.forLanguage("Hindi")
        let hint = ProductConsent.confirmHint(
            ConfirmVerdict(ok: false, reason: .nothingChosen),
            products: nil,
            copy: hindi
        ) { $0.name }
        XCTAssertEqual(hint, hindi.hintNothingChosen)
    }

    func testTheSavedAnswerLabelFollowsTheLanguage() {
        let hindi = NoticeChromeCopy.forLanguage("Hindi")
        XCTAssertEqual(
            SelectionControlLogic.optionLabel(hindi.yes, value: true, recordedAnswer: true, copy: hindi),
            "हाँ सहेजा गया उत्तर: हाँ"
        )
    }
}
