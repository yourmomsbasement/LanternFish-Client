package app.lanternfish

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ServerAddressTest {
    @Test
    fun bareHostTriesAsTypedThenDefaultPort() {
        assertEquals(listOf("http://jelly.local", "http://jelly.local:8096"), ServerAddress.candidates("jelly.local"))
    }

    @Test
    fun hostWithPortIsUsedAsIs() {
        assertEquals(listOf("http://192.168.1.10:8096"), ServerAddress.candidates(" 192.168.1.10:8096/ "))
    }

    @Test
    fun explicitSchemeAndPathAreKept() {
        assertEquals(listOf("https://media.example.com/jellyfin"), ServerAddress.candidates("https://media.example.com/jellyfin/"))
    }

    @Test
    fun webClientUrlIsTrimmedToTheServer() {
        assertEquals(listOf("http://nas:8096"), ServerAddress.candidates("http://nas:8096/web/index.html"))
    }

    @Test
    fun garbageIsRejected() {
        assertEquals(emptyList<String>(), ServerAddress.candidates(""))
        assertEquals(emptyList<String>(), ServerAddress.candidates("not an address"))
    }

    @Test
    fun sameOriginComparesSchemeHostAndPort() {
        assertTrue(ServerAddress.sameOrigin("http://nas:8096", "http://NAS:8096/web/index.html#/home"))
        assertTrue(ServerAddress.sameOrigin("https://media.example.com/jellyfin", "https://media.example.com:443/x"))
        assertFalse(ServerAddress.sameOrigin("http://nas:8096", "http://nas:8920/web/"))
        assertFalse(ServerAddress.sameOrigin("http://nas:8096", "https://nas:8096/web/"))
        assertFalse(ServerAddress.sameOrigin("http://nas:8096", "https://www.themoviedb.org/movie/1"))
    }
}
