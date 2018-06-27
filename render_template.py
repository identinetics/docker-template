#!/usr/bin/python3

import argparse
import os
import sys
import yaml
from jinja2 import Template

class Cli:
    """ define CLI invocation """
    def __init__(self):
        self._parser = argparse.ArgumentParser(description='Render Jinja2 template with yaml argument file\n'
                                               'Arguments must be strucutred in a dict of dicts, comprisong sections with a list of key-value pairs')
        self._parser.add_argument('arguments_file', help='Arguments file, YAML')
        self._parser.add_argument('template_file', help='Jinja2 template file')
        self._parser.add_argument('arguments_section', help='Section in the arguments file to apply to the template')
        self.args = self._parser.parse_args()


def main():
    if sys.version_info < (3, 4):
        raise "must use python 3.4 or higher"
    cli = Cli()
    template_vars = read_template_arguments(cli.args)
    render_template(cli.args, template_vars)


def read_template_arguments(args):
    try:
        fd_yaml = open(args.arguments_file, 'r', encoding='UTF-8-sig')
    except Exception as e:
        print('cannot open template_arguments: {}\n{}'.format(os.path.abspath(args.arguments_file), str(e)))
        exit(1)

    try:
        template_vars = yaml.load(fd_yaml)
        return template_vars
    except yaml.YAMLError as e:
        print(e)
        exit(1)


def render_template(args, template_vars):
    try:
        fd_templ = open(args.template_file, 'r', encoding='UTF-8-sig')
    except Exception as e:
        print('cannot open template {}\n{}'.format(os.path.abspath(args.template_file), str(e)))
        exit(1)
    t = Template(fd_templ.read())
    print( t.render(template_vars[args.arguments_section]))


main()