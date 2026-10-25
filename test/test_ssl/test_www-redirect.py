import pytest


@pytest.mark.parametrize("url,expected", [
    ("http://web2.nginx-proxy.tld/port", "https://web2.nginx-proxy.tld/port"),
    ("http://www.web2.nginx-proxy.tld/port", "https://web2.nginx-proxy.tld/port"),
    ("https://www.web2.nginx-proxy.tld/port", "https://web2.nginx-proxy.tld/port"),
    ("https://www.web2.nginx-proxy.tld/foo/bar?baz=1", "https://web2.nginx-proxy.tld/foo/bar?baz=1"),
    ("http://www.web3.nginx-proxy.tld/port", "http://web3.nginx-proxy.tld/port"),
    ("https://www.web3.nginx-proxy.tld/port", "https://web3.nginx-proxy.tld/port"),
    ("http://www.web4.nginx-proxy.tld/web4/port", "http://web4.nginx-proxy.tld/web4/port"),
    ("http://www.web4.nginx-proxy.tld/", "http://web4.nginx-proxy.tld/"),
])
def test_redirect(docker_compose, nginxproxy, url, expected):
    r = nginxproxy.get(url, allow_redirects=False)
    assert r.status_code == 301
    assert r.headers["Location"] == expected


@pytest.mark.parametrize("url,port", [
    ("https://web2.nginx-proxy.tld/port", 82),
    ("http://web3.nginx-proxy.tld/port", 83),
    ("https://web3.nginx-proxy.tld/port", 83),
    ("http://web4.nginx-proxy.tld/web4/port", 84),
    ("https://www.nginx-proxy.tld/port", 85),
])
def test_non_www_and_opted_out_hosts_are_forwarded(docker_compose, nginxproxy, url, port):
    r = nginxproxy.get(url, allow_redirects=False)
    assert r.status_code == 200
    assert f"answer from port {port}\n" in r.text


def test_acme_challenge_is_not_redirected(docker_compose, nginxproxy, acme_challenge_path):
    for host in ["www.web2.nginx-proxy.tld", "www.web3.nginx-proxy.tld"]:
        r = nginxproxy.get(f"http://{host}/{acme_challenge_path}", allow_redirects=False)
        assert r.status_code == 200
