package app.lanternfish

import org.junit.Assert.assertEquals
import org.junit.Test

class IndexInjectorTest {
    @Test
    fun scriptsGoRightAfterHead() {
        val html = "<!doctype html><html><head lang=\"en\"><meta charset=\"utf-8\"><script src=\"main.js\"></script></head></html>"
        assertEquals(
            "<!doctype html><html><head lang=\"en\"><script>x</script><meta charset=\"utf-8\"><script src=\"main.js\"></script></head></html>",
            IndexInjector.inject(html, "<script>x</script>"),
        )
    }

    @Test
    fun withoutHeadScriptsArePrepended() {
        assertEquals("<script>x</script><p>hi</p>", IndexInjector.inject("<p>hi</p>", "<script>x</script>"))
    }
}
